class AnalyticsController < ApplicationController
  before_action :require_authentication
  before_action :require_pro

  RANGES = {
    "7"   => { label: "7 days",  days: 7 },
    "30"  => { label: "30 days", days: 30 },
    "90"  => { label: "90 days", days: 90 },
    "all" => { label: "All time", days: nil }
  }.freeze

  def index
    @range_key   = RANGES.key?(params[:range]) ? params[:range] : "30"
    @range_label = RANGES[@range_key][:label]
    days         = RANGES[@range_key][:days]
    since        = days&.days&.ago
    chart_days   = days || [ days_since_signup, 90 ].min

    views   = current_user.profile_views
    scoped  = since ? views.where(viewed_at: since..) : views
    clicks  = current_user.entry_clicks
    clicks_scoped = since ? clicks.where(clicked_at: since..) : clicks

    @views = {
      total:         scoped.count,
      unique:        scoped.distinct.count(:ip_hash),
      last_visited:  views.maximum(:viewed_at),
      daily:         views.daily_counts(days: chart_days),
      top_countries: scoped.where.not(country: [ nil, "" ])
                           .group(:country).order("count_all DESC").limit(10).count,
      top_referrers: scoped.where.not(referrer: [ nil, "" ])
                           .group(:referrer).order("count_all DESC").limit(10).count
    }

    entry_click_counts = clicks_scoped.group(:entry_id).order("count_all DESC").count
    entries_by_id = Entry.where(id: entry_click_counts.keys).index_by(&:id)
    last_clicks   = clicks_scoped.group(:entry_id).maximum(:clicked_at)

    @entry_clicks = {
      total:       clicks_scoped.count,
      leaderboard: entry_click_counts.filter_map { |id, count|
                     entry = entries_by_id[id]
                     [ entry, count, last_clicks[id] ] if entry
                   }
    }

    entries_in_range = since ? current_user.entries.where(occurred_at: since..) : current_user.entries
    @entries_breakdown = {
      total:        current_user.entries.count,
      in_range:     entries_in_range.count,
      visible:      entries_in_range.visible.count,
      private_ct:   entries_in_range.where(visibility: :private_entry).count,
      hidden:       entries_in_range.where(hidden: true).count,
      by_type:      entries_in_range.group(:entry_type).count,
      by_source:    entries_in_range.group(:source).count,
      weekly:       weekly_entry_counts(chart_days),
      current_streak: current_user.current_streak
    }
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
end
