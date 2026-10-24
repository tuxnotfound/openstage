module Progress
  # What the page's chart script switches on without a request: every public
  # commit by day (in the builder's zone) and repo, and every shipped or
  # published entry, from the first one on. The script recomputes each window
  # from them as TallyService does; this is the view it opens on.
  class ExportService < ApplicationService
    # range: the window to open on; repos: the projects in view, none for all.
    attr_accessor :user, :range, :repos
    attr_reader :payload

    validates :user, presence: true

    private

    def execute
      projects = Projects.new(entries).all
      @payload = {
        today: Time.current.in_time_zone(user.zone).to_date.iso8601,
        firstActivity: first_activity&.iso8601,
        projects: projects.map { |project| { repo: project.repo, name: project.name, rank: project.rank } },
        commits: commits_by_day,
        items: items(projects.map(&:name)),
        range: Window::RANGES.include?(range) ? range : Window::DEFAULT,
        selected: projects.map(&:repo) & Array(repos)
      }
    end

    def entries
      @entries ||= user.entries.publicly_visible.without_tooling_noise
    end

    def first_activity
      entries.commits.or(entries.highlights).minimum(:occurred_at)&.in_time_zone(user.zone)&.to_date
    end

    # {"2026-10-23" => {"me/app" => 3, "" => 1}}: "" for commits with no repo.
    def commits_by_day
      day = Arel.sql(LocalDay.of("entries.occurred_at", user.zone))
      entries.commits.group(day, :repo_name).count.each_with_object({}) do |((date, repo), count), days|
        (days[date.to_date.iso8601] ||= {})[repo.to_s] = count
      end
    end

    # Oldest first, as the page lists them newest first.
    def items(names)
      entries.highlights.order(:occurred_at, :id).map do |entry|
        { id: entry.id, date: entry.occurred_at.in_time_zone(user.zone).to_date.iso8601,
          shipped: Entry::SHIPPED_TYPES.include?(entry.entry_type), repo: entry.repo_name, title: entry.title,
          runIn: RunIn.capped(RunIn.of(entry.title, entry.body, names)).to_s, url: link(entry.url) }
      end
    end

    # Only an http(s) address becomes a link, as safe_external_url allows.
    def link(url)
      url if %w[http https].include?(URI.parse(url.to_s).scheme)
    rescue URI::InvalidURIError
      nil
    end
  end
end
