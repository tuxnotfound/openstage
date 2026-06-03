class AnalyticsController < ApplicationController
  before_action :require_authentication
  before_action :require_pro

  RANGES = {
    "7"   => { label: "7 days",  days: 7 },
    "30"  => { label: "30 days", days: 30 },
    "90"  => { label: "90 days", days: 90 },
    "all" => { label: "All time", days: nil }
  }.freeze

  HEATMAP_WEEKS = 12

  def index
    @range_key   = RANGES.key?(params[:range]) ? params[:range] : "30"
    @range_label = RANGES[@range_key][:label]
    days         = RANGES[@range_key][:days]
    since        = days&.days&.ago
    prior_since  = days ? (days * 2).days.ago : nil
    prior_until  = since
    chart_days   = days || [ days_since_signup, 90 ].min

    views   = current_user.profile_views
    clicks  = current_user.entry_clicks
    entries = current_user.entries
    badges  = current_user.badge_impressions

    scoped_views   = since ? views.where(viewed_at: since..) : views
    scoped_clicks  = since ? clicks.where(clicked_at: since..) : clicks
    scoped_entries = since ? entries.where(occurred_at: since..) : entries
    scoped_badges  = since ? badges.where(viewed_at: since..) : badges

    @views = {
      total:         scoped_views.count,
      unique:        scoped_views.distinct.count(:ip_hash),
      last_visited:  views.maximum(:viewed_at),
      daily:         views.daily_counts(days: chart_days),
      top_countries: scoped_views.where.not(country: [ nil, "" ])
                                 .group(:country).order("count_all DESC").limit(10).count,
      top_referrers: scoped_views.where.not(referrer: [ nil, "" ])
                                 .group(:referrer).order("count_all DESC").limit(10).count
    }

    @views[:by_source] = group_by_source(
      scoped_views.group(:referrer).count,
      total: @views[:total]
    )

    entry_click_counts = scoped_clicks.group(:entry_id).order("count_all DESC").count
    entries_by_id = Entry.where(id: entry_click_counts.keys).index_by(&:id)
    last_clicks   = scoped_clicks.group(:entry_id).maximum(:clicked_at)

    @entry_clicks = {
      total:       scoped_clicks.count,
      leaderboard: build_leaderboard(entry_click_counts, entries_by_id, last_clicks)
    }

    @entries_breakdown = {
      total:          entries.count,
      in_range:       scoped_entries.count,
      visible:        scoped_entries.visible.count,
      private_ct:     scoped_entries.where(visibility: :private_entry).count,
      hidden:         scoped_entries.where(hidden: true).count,
      by_type:        scoped_entries.group(:entry_type).count,
      by_source:      scoped_entries.group(:source).count,
      weekly:         weekly_entry_counts(chart_days),
      heatmap:        heatmap_counts,
      current_streak: current_user.current_streak
    }

    @badge_stats = {
      badge_total:       scoped_badges.where(kind: "badge").count,
      badge_unique:      scoped_badges.where(kind: "badge").distinct.count(:ip_hash),
      embed_total:       scoped_badges.where(kind: "embed").count,
      embed_unique:      scoped_badges.where(kind: "embed").distinct.count(:ip_hash),
      badge_last_seen:   badges.where(kind: "badge").maximum(:viewed_at),
      embed_last_seen:   badges.where(kind: "embed").maximum(:viewed_at)
    }

    @deltas = prior_since ? compute_deltas(prior_since, prior_until) : nil
  end

  private

  def require_pro
    return if current_user&.pro?
    redirect_to dashboard_path, alert: "Analytics is a Pro feature."
  end

  def days_since_signup
    days = ((Date.current - current_user.created_at.to_date).to_i + 1)
    [ days, 7 ].max
  end

  def group_by_source(referrer_counts, total:)
    buckets = Hash.new(0)
    referrer_counts.each do |referrer, count|
      buckets[ReferrerClassifier.classify(referrer)] += count
    end
    buckets.sort_by { |_, c| -c }.to_h
  end

  def build_leaderboard(counts_by_entry_id, entries_by_id, last_clicks)
    return [] if counts_by_entry_id.empty?

    entry_ids = entries_by_id.values.map(&:id)
    created_ats = Entry.where(id: entry_ids).pluck(:id, :created_at).to_h

    # Total profile views since each entry's creation, batched into one query.
    views_since = views_since_per_entry(entry_ids, created_ats)

    counts_by_entry_id.filter_map do |id, click_count|
      entry = entries_by_id[id]
      next unless entry

      denominator = views_since[id] || 0
      rate = denominator >= 10 ? (click_count.to_f / denominator * 100).round(1) : nil
      {
        entry:        entry,
        clicks:       click_count,
        last_clicked: last_clicks[id],
        views_since:  denominator,
        click_rate:   rate
      }
    end
  end

  def views_since_per_entry(entry_ids, created_ats)
    return {} if entry_ids.empty?

    earliest = created_ats.values.min
    return entry_ids.index_with { 0 } unless earliest

    # Pull all profile views since the earliest leaderboard entry's creation,
    # then bucket by how many predate vs. follow each entry's created_at.
    view_times = current_user.profile_views
                             .where(viewed_at: earliest..)
                             .pluck(:viewed_at)
                             .sort

    entry_ids.index_with do |id|
      cutoff = created_ats[id]
      cutoff ? view_times.count { |t| t >= cutoff } : 0
    end
  end

  def weekly_entry_counts(days)
    start = days.days.ago.to_date.beginning_of_week
    weeks = ((Date.current - start).to_i / 7) + 1
    grouped = current_user.entries
                          .where(occurred_at: start.beginning_of_day..)
                          .group("DATE_TRUNC('week', occurred_at AT TIME ZONE 'UTC')")
                          .count
    (0...weeks).each_with_object({}) do |i, h|
      week_start = start + (i * 7)
      key = grouped.keys.find { |k| k.to_date == week_start }
      h[week_start.to_s] = key ? grouped[key] : 0
    end
  end

  # 12 weeks of daily counts (84 days), keyed by ISO date string.
  def heatmap_counts
    start = (HEATMAP_WEEKS * 7 - 1).days.ago.to_date.beginning_of_week
    grouped = current_user.entries
                          .where(occurred_at: start.beginning_of_day..)
                          .group("DATE(occurred_at AT TIME ZONE 'UTC')")
                          .count
    grouped = grouped.transform_keys(&:to_date)
    end_date = Date.current
    (start..end_date).each_with_object({}) do |date, h|
      h[date.to_s] = grouped[date] || 0
    end
  end

  def compute_deltas(prior_since, prior_until)
    prior_views_rel  = current_user.profile_views.where(viewed_at: prior_since...prior_until)
    prior_clicks_rel = current_user.entry_clicks.where(clicked_at: prior_since...prior_until)
    prior_entries_rel = current_user.entries.where(occurred_at: prior_since...prior_until)

    prior = {
      views_total:    prior_views_rel.count,
      views_unique:   prior_views_rel.distinct.count(:ip_hash),
      clicks_total:   prior_clicks_rel.count,
      entries_total:  prior_entries_rel.count
    }

    {
      views_total:   delta(@views[:total],            prior[:views_total]),
      views_unique:  delta(@views[:unique],           prior[:views_unique]),
      clicks_total:  delta(@entry_clicks[:total],     prior[:clicks_total]),
      entries_total: delta(@entries_breakdown[:in_range], prior[:entries_total])
    }
  end

  def delta(current, prior)
    return { current: current, prior: prior, pct: nil } if prior.zero?
    pct = ((current - prior).to_f / prior * 100).round
    { current: current, prior: prior, pct: pct }
  end
end
