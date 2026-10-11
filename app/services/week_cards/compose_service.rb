module WeekCards
  # Puts together everything a week card shows, from the builder's public
  # entries only: commits per project per day, what they shipped and published,
  # and one headline per day. The headline is the builder's own words when they
  # wrote one; otherwise what they shipped or published that day; otherwise a
  # plain count. Never a bare commit message: those mean little without context.
  class ComposeService < ApplicationService
    PATTERNS = %w[solid hatch outline dots cross].freeze
    SHIPPED = %w[milestone released].freeze
    PUBLISHED = %w[posted link note].freeze

    Card = Data.define(:week_card, :user, :label, :dates, :days, :projects, :totals, :best_run, :streak, :draft)
    Day = Data.define(:date, :label, :segments, :total, :headline, :suggestions, :active)
    Segment = Data.define(:project, :n, :pattern)
    Project = Data.define(:name, :n, :pattern, :shown)
    Headline = Data.define(:text, :kind, :project, :source)
    Totals = Data.define(:commits, :active_days, :projects, :shipped, :published)

    attr_accessor :week_card
    attr_reader :card

    validates :week_card, presence: true

    private

    def execute
      days = week_card.days.map { |date| compose_day(date) }
      week_totals = totals(days)
      @card = Card.new(
        week_card: week_card, user: week_card.user, label: "Week #{week_card.week_start.cweek}",
        dates: date_range_label, days: days, projects: projects, totals: week_totals,
        best_run: best_run(days), streak: current_week? ? week_card.user.public_activity_streak : nil,
        draft: draft(days, week_totals)
      )
    end

    def compose_day(date)
      counts = shown_counts_on(date)
      highlights = highlights_on(date)
      Day.new(
        date: date, label: date.strftime("%a %-d").upcase,
        segments: counts.map { |name, n| Segment.new(project: name, n: n, pattern: pattern_for(name)) },
        total: counts.values.sum, headline: headline_on(date, counts, highlights),
        suggestions: suggestions_on(date, highlights), active: counts.any? || highlights.any?
      )
    end

    def headline_on(date, counts, highlights)
      written = week_card.headline_on(date)
      return Headline.new(text: written["text"], kind: written["kind"], project: nil, source: :builder) if written

      highlight = highlights.min_by { |entry| SHIPPED.include?(entry.entry_type) ? 0 : 1 }
      return Headline.new(text: highlight_text(highlight), kind: kind_of(highlight), project: project_of(highlight), source: :entry) if highlight
      return if counts.empty?

      name, n = counts.max_by { |_name, count| count }
      Headline.new(text: "#{n} #{'commit'.pluralize(n)} in #{name}", kind: "built", project: name, source: :count)
    end

    # Starting points for the builder's own words: what they logged, then what
    # they committed. The builder edits; nothing goes on the card as is.
    def suggestions_on(date, highlights)
      logged = highlights.map(&:title)
      committed = commits.select { |entry| entry.occurred_at.to_date == date && shown?(entry) }.map(&:title)
      (logged + committed).map { |title| title.lines.first.to_s.strip }.reject(&:blank?).uniq.first(5)
    end

    def highlight_text(entry)
      return entry.title unless entry.entry_type == "posted"

      host = URI.parse(entry.url.to_s).host.to_s
      return "Posted on X" if host.end_with?("x.com", "twitter.com")
      return "Posted on Bluesky" if host.end_with?("bsky.app")

      entry.title
    rescue URI::InvalidURIError
      entry.title
    end

    def kind_of(entry)
      SHIPPED.include?(entry.entry_type) ? "shipped" : "published"
    end

    def entries
      @entries ||= week_card.user.entries.publicly_visible.without_tooling_noise
                            .where(occurred_at: week_card.week_start.beginning_of_day..(week_card.week_start + 6).end_of_day)
                            .order(:occurred_at).to_a
    end

    def commits
      @commits ||= entries.select { |entry| entry.github? && entry.shipped? }
    end

    def highlights_on(date)
      entries.select { |entry| (SHIPPED + PUBLISHED).include?(entry.entry_type) && entry.occurred_at.to_date == date }
    end

    def shown_counts_on(date)
      commits.select { |entry| entry.occurred_at.to_date == date && shown?(entry) }
             .group_by { |entry| project_of(entry) }.transform_values(&:size)
             .sort_by { |name, n| [ -project_totals.fetch(name, 0), -n ] }.to_h
    end

    def shown?(entry)
      week_card.shows_project?(project_of(entry))
    end

    # Short repo names, unless two repos this week share one.
    def project_of(entry)
      return if entry.repo_name.blank?

      short = entry.repo_name.split("/").last
      ambiguous_names.include?(short) ? entry.repo_name : short
    end

    def ambiguous_names
      @ambiguous_names ||= entries.map(&:repo_name).compact.uniq.group_by { |name| name.split("/").last }
                                  .select { |_short, full| full.size > 1 }.keys
    end

    def project_totals
      @project_totals ||= commits.group_by { |entry| project_of(entry) }.transform_values(&:size)
                                 .sort_by { |name, n| [ -n, name.to_s ] }.to_h
    end

    def projects
      shown = project_totals.keys.select { |name| week_card.shows_project?(name) }
      project_totals.map { |name, n| Project.new(name: name, n: n, pattern: pattern_for(name), shown: shown.include?(name)) }
    end

    def pattern_for(name)
      index = project_totals.keys.select { |project| week_card.shows_project?(project) }.index(name)
      index ? PATTERNS.fetch(index, "outline") : nil
    end

    def totals(days)
      kinds = days.filter_map(&:headline).reject { |headline| headline.source == :count }.map(&:kind)
      Totals.new(
        commits: days.sum(&:total), active_days: days.count(&:active),
        projects: project_totals.keys.count { |name| week_card.shows_project?(name) },
        shipped: kinds.count("shipped"), published: kinds.count("published")
      )
    end

    def best_run(days)
      days.chunk_while { |a, b| a.active && b.active }.select { |run| run.first.active }.map(&:size).max || 0
    end

    # A starting point for the post that goes out with the card, built from the
    # card's own facts. The builder rewrites it.
    def draft(days, week_totals)
      lines = days.filter_map(&:headline).reject { |headline| headline.source == :count }
                  .map { |headline| "- #{headline.text}" }
      summary = "Week #{week_card.week_start.cweek}: #{week_totals.commits} #{'commit'.pluralize(week_totals.commits)} " \
                "on #{week_totals.active_days} of 7 days."
      ([ summary ] + lines).join("\n")
    end

    def current_week?
      week_card.days.include?(Date.current)
    end

    def date_range_label
      first, last = week_card.week_start, week_card.week_start + 6
      start = first.strftime("%b %-d")
      finish = first.month == last.month ? last.strftime("%-d") : last.strftime("%b %-d")
      "#{start} – #{finish}, #{last.year}"
    end
  end
end
