module Analytics
  # Everything the Pro analytics page shows for a window, the numbers drawn
  # and the pages in view, on the chart filter every chart page shares: a row
  # per page, the builder's own and one per project, as the public page
  # orders and colours them, each counting Openstage's own four numbers and a
  # project also its commits and site visits, as its builder shows them; what
  # Progress::DrawService makes of their counts, each number's total and
  # change for the pages in view and the one chart of the numbers drawn; and
  # where visitors came from, the links they followed and where the badge and
  # embed showed.
  class ReportService < ApplicationService
    # It opens on the last 30 days and on commits alone.
    DEFAULT_RANGE = "30d".freeze
    DEFAULT_SHOW = %w[commits].freeze
    Link = Data.define(:title, :page, :count)
    TOP = 6

    # range: a Progress::Window range, nil for the default; show: the numbers
    # asked for, by key in line order; picked: page keys, none for all of them.
    attr_accessor :user, :range, :show, :picked
    # period: the Window the totals cover; rows: a Progress::Row per page, in
    # the pages' fixed order; drawing: the DrawService of the totals and the chart.
    attr_reader :period, :rows, :counts, :drawing, :sources, :countries, :links, :shown

    delegate :totals, :drawn, :default_drawn, :window, :chart, :value, :previous, to: :drawing

    validates :user, presence: true

    def selected
      rows.select(&:on)
    end

    # The pages in view, by key; none for all of them.
    def selected_keys
      rows.all?(&:on) ? [] : selected.map(&:key)
    end

    # The table's numbers: every one a page shows.
    def columns
      totals.map(&:number)
    end

    # Analytics is the builder's own and every page has a box: no switches
    # for what visitors see, and no project off their page.
    def builder
      false
    end

    def off_page
      []
    end

    private

    def execute
      @period = Progress::Window.new(range: range.presence_in(Progress::Window::RANGES) || DEFAULT_RANGE, today: today, first_activity: nil)
      return unless count

      @rows = pages
      return unless draw

      read_visits
      @links = top_links
      @shown = badges
    end

    def today
      @today ||= Time.current.in_time_zone(user.zone).to_date
    end

    # The window before the range too, for the changes; every day for all time.
    def count
      start = FindStartService.new(user: user)
      return unless run(start)

      service = CountService.new(user: user, from: period.span_before&.first)
      @counts = Progress::Counts.new(days: service.counts, firsts: start.firsts) if run(service)
    end

    # The builder's page first, then each project, every page in view when
    # the pages picked name none of theirs.
    def pages
      synced = user.github_repos.where(full_name: projects.map(&:repo)).index_by(&:full_name)
      all = [ [ CountService::PAGE, "Your page", nil ] ] + projects.map { |project| [ project.repo, project.name, project.rank ] }
      in_view = Array(picked) & all.map(&:first)
      all.map { |key, name, rank| row(key, name, rank, synced[key], in_view.empty? || in_view.include?(key)) }
    end

    def projects
      @projects ||= Progress::Projects.new(user.entries.publicly_visible.without_tooling_noise).all
    end

    # A page counts a number once it has counted it on any day; a project
    # shows the ones its builder picked to show, and Openstage's own always.
    def row(key, name, rank, repo, on)
      counted = Progress::Numbers::ALL.select { |number| counts.first_day(number.key, [ key ]) }
      shown = counted.select { |number| !number.picked || repo.nil? || repo.shows?(number.key) }
      Progress::Row.new(key: key, name: name, rank: rank, repo: repo, on: on, counted: counted.map(&:key), shown: shown.map(&:key))
    end

    def draw
      service = Progress::DrawService.new(rows: rows, counts: counts, period: period, show: show, default_show: DEFAULT_SHOW, per: "page")
      @drawing = service if run(service)
    end

    # Hosts grouped as the old analytics grouped them (Hacker News, GitHub,
    # Direct...), and the countries Cloudflare names, busiest first.
    def read_visits
      views = [ (user.profile_views if page_for(CountService::PAGE)), user.project_views.where(repo_name: selected.map(&:key)) ].compact
      views = views.map { |scope| scope.where(viewed_at: times) }
      @sources = tally(views.flat_map { |scope| scope.group(:referrer).count.to_a }) { |host| ReferrerClassifier.classify(host) }
      @countries = tally(views.flat_map { |scope| scope.where.not(country: [ nil, "" ]).group(:country).count.to_a }, &:itself).first(5)
    end

    def tally(pairs)
      pairs.each_with_object(Hash.new(0)) { |(key, count), sums| sums[yield(key)] += count }.sort_by { |key, count| [ -count, key ] }.first(TOP)
    end

    # Entry links and project buttons, together, busiest first.
    def top_links
      (entry_links + button_links).sort_by { |link| [ -link.count, link.title ] }.first(TOP)
    end

    def entry_links
      clicks = user.entry_clicks.joins(:entry).where(clicked_at: times).group(:entry_id).count
      user.entries.where(id: clicks.keys).filter_map do |entry|
        page = page_for(entry.repo_name || CountService::PAGE)
        Link.new(title: entry.title, page: page, count: clicks[entry.id]) if page
      end
    end

    def button_links
      repos = user.github_repos.index_by(&:full_name)
      user.project_clicks.where(clicked_at: times).group(:repo_name, :kind).count.filter_map do |(repo, kind), count|
        page = page_for(repo)
        host = host_of(repos[repo]&.outbound_url("visit"))
        title = kind == "visit" ? "Visit #{host || 'the website'}" : "View on GitHub"
        Link.new(title: title, page: page, count: count) if page
      end
    end

    # [kind, times shown, sites] for the README badge and the embed.
    def badges
      seen = user.badge_impressions.where(viewed_at: times)
      %w[badge embed].map { |kind| [ kind, seen.where(kind: kind).count, seen.where(kind: kind).distinct.count(:referrer) ] }
    end

    def host_of(url)
      URI(url).host if url
    rescue URI::InvalidURIError
      nil
    end

    # A page in view.
    def page_for(key)
      selected.find { |row| row.key == key }
    end

    # The window's days in the builder's zone; every day before today for all time.
    def times
      first = period.span&.first
      (first&.in_time_zone(user.zone))..(today.in_time_zone(user.zone).end_of_day)
    end

    def run(service)
      service.call
      absorb_errors(service)
    end
  end
end
