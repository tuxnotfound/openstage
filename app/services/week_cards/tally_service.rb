module WeekCards
  # Counts one week of a builder's public work, in the card's time zone:
  # commits per project per day and per hour, what they shipped and published
  # and when, and one headline per day. The headline is the builder's own words when they wrote
  # one; otherwise what they shipped or published that day; otherwise a plain
  # count. Never a bare commit message: those mean little without context.
  class TallyService < ApplicationService
    SHIPPED = %w[milestone released].freeze
    PUBLISHED = %w[posted link note].freeze
    # The most starting points a day's menu offers.
    SUGGESTIONS = 30

    Tally = Data.define(:days, :projects, :totals, :best_run, :commits)
    # hours: each hour of the day with commits, to its commits by project.
    Day = Data.define(:date, :label, :segments, :total, :headline, :suggestions, :active, :hours, :launches, :posts)
    Segment = Data.define(:project, :n, :slot)
    Project = Data.define(:name, :n, :slot, :shown)
    Headline = Data.define(:text, :kind, :project, :source)
    # A launch or a post the builder logged, at its time in the card's zone.
    Log = Data.define(:title, :url, :at)
    # shipped and published count the days a headline says so; launches and
    # posts count what was logged. peak_hour starts the busiest two hours.
    Totals = Data.define(:commits, :active_days, :projects, :shipped, :published, :launches, :posts, :peak_hour)

    attr_accessor :week_card
    attr_reader :tally

    validates :week_card, presence: true

    # The whole day's commits, busiest project first: "6 commits in wheels-off
    # and openstage", and past two projects "16 commits in 3 projects".
    def self.count_line(counts)
      total = counts.sum { |_name, n| n }
      names = counts.sort_by.with_index { |(_name, n), i| [ -n, i ] }.map(&:first)
      where = names.size > 2 ? "#{names.size} projects" : names.join(" and ")
      "#{total} #{'commit'.pluralize(total)} in #{where}"
    end

    # 19 for 19:00 – 21:00, from commits counted by hour of day; nil without
    # any.
    def self.peak_hour(counts)
      return if counts.sum.zero?

      (0..23).max_by { |hour| counts[hour] + counts[(hour + 1) % 24] }
    end

    private

    def execute
      days = week_card.days.map { |date| tally_day(date) }
      @tally = Tally.new(days: days, projects: projects, totals: totals(days), best_run: best_run(days),
                         commits: commits.select { |entry| shown?(entry) })
    end

    def tally_day(date)
      counts = shown_counts_on(date)
      highlights = highlights_on(date)
      Day.new(
        date: date, label: date.strftime("%a %-d").upcase,
        segments: counts.map { |name, n| Segment.new(project: name, n: n, slot: slot_for(name)) },
        total: counts.values.sum, headline: headline_on(date, counts, highlights),
        suggestions: suggestions_on(date, highlights), active: counts.any? || highlights.any?,
        hours: hours_on(date), launches: logs(highlights, SHIPPED), posts: logs(highlights, PUBLISHED)
      )
    end

    def headline_on(date, counts, highlights)
      written = week_card.headline_on(date)
      return Headline.new(text: written["text"], kind: written["kind"], project: nil, source: :builder) if written

      highlight = highlights.min_by { |entry| SHIPPED.include?(entry.entry_type) ? 0 : 1 }
      return Headline.new(text: highlight_text(highlight), kind: kind_of(highlight), project: project_of(highlight), source: :entry) if highlight
      return if counts.empty?

      name, _n = counts.max_by { |_name, count| count }
      Headline.new(text: self.class.count_line(counts), kind: "built", project: name, source: :count)
    end

    # Starting points for the builder's own words, for the day's menu: what
    # they logged, then what they committed. The builder edits; nothing goes on
    # the card as is.
    def suggestions_on(date, highlights)
      logged = highlights.map(&:title)
      committed = shown_commits_on(date).map(&:title)
      (logged + committed).map { |title| title.lines.first.to_s.strip }.reject(&:blank?).uniq.first(SUGGESTIONS)
    end

    def hours_on(date)
      shown_commits_on(date).group_by { |entry| local_time(entry).hour }.sort.to_h
                            .transform_values { |entries| entries.group_by { |entry| project_of(entry) }.transform_values(&:size) }
    end

    def logs(highlights, types)
      highlights.select { |entry| types.include?(entry.entry_type) }
                .map { |entry| Log.new(title: entry.title, url: entry.url, at: local_time(entry)) }
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
                            .where(occurred_at: week_card.time_range).order(:occurred_at).to_a
    end

    def local_time(entry)
      entry.occurred_at.in_time_zone(week_card.zone)
    end

    def local_date(entry)
      local_time(entry).to_date
    end

    def commits
      @commits ||= entries.select { |entry| entry.github? && entry.shipped? }
    end

    def highlights_on(date)
      entries.select { |entry| (SHIPPED + PUBLISHED).include?(entry.entry_type) && local_date(entry) == date }
    end

    def shown_commits_on(date)
      commits.select { |entry| local_date(entry) == date && shown?(entry) }
    end

    def shown_counts_on(date)
      shown_commits_on(date).group_by { |entry| project_of(entry) }.transform_values(&:size)
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

    def shown_projects
      @shown_projects ||= project_totals.keys.select { |name| week_card.shows_project?(name) }
    end

    def projects
      project_totals.map { |name, n| Project.new(name: name, n: n, slot: slot_for(name), shown: shown_projects.include?(name)) }
    end

    # The colour a project gets on the card, busiest first.
    def slot_for(name)
      shown_projects.index(name)
    end

    def totals(days)
      kinds = days.filter_map(&:headline).reject { |headline| headline.source == :count }.map(&:kind)
      Totals.new(
        commits: days.sum(&:total), active_days: days.count(&:active), projects: shown_projects.size,
        shipped: kinds.count("shipped"), published: kinds.count("published"),
        launches: days.sum { |day| day.launches.size }, posts: days.sum { |day| day.posts.size },
        peak_hour: self.class.peak_hour(hour_counts(days))
      )
    end

    def hour_counts(days)
      counts = Array.new(24, 0)
      days.each { |day| day.hours.each { |hour, projects| counts[hour] += projects.values.sum } }
      counts
    end

    def best_run(days)
      days.chunk_while { |a, b| a.active && b.active }.select { |run| run.first.active }.map(&:size).max || 0
    end
  end
end
