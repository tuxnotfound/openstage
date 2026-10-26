module Analytics
  # Everything the Pro analytics page shows, for a window, the pages picked and
  # the numbers charted: the builder's page and one per project, as the public
  # page orders and colours them. Totals and the charts come from
  # CountService; where visitors came from, the links they followed and where
  # the badge and embed showed are read here.
  class ReportService < ApplicationService
    # key: CountService::PAGE or a repo's full name; rank: its colour, nil for the builder's page.
    Page = Data.define(:key, :name, :rank)
    Link = Data.define(:title, :page, :count)
    TOP = 6
    # Charted until others are picked: the two that matter most.
    CHARTED = %w[commits site].freeze

    # picked: page keys, none for all of them; metrics: the numbers to chart.
    attr_accessor :user, :range, :picked, :metrics
    attr_reader :window, :pages, :selected, :counts, :sources, :countries, :links, :shown

    validates :user, presence: true

    # One page's count, or the selection's, over the window or the one before.
    def total(metric, page: nil, days: window.days)
      Array(page || selected).sum { |each| days.sum { |day| counts.dig(metric, each.key, day).to_i } }
    end

    # Percent against the days before; nil when there were none.
    def change(metric, page: nil)
      before = total(metric, page: page, days: window.previous_days)
      ((100.0 * total(metric, page: page) / before) - 100).round if before.positive?
    end

    # A number per point of its chart, for one page.
    def series(page, metric)
      window.buckets.map { |bucket| (bucket.first..bucket.last).sum { |day| counts.dig(metric, page.key, day).to_i } }
    end

    private

    def execute
      @metrics = CountService::METRICS.select { |each| Array(metrics).include?(each) }.presence || CHARTED
      @pages = [ Page.new(key: CountService::PAGE, name: "Your page", rank: nil) ] + projects
      @selected = pages.select { |page| Array(picked).include?(page.key) }.presence || pages
      start = FindStartService.new(user: user, pages: selected.map(&:key))
      start.call
      return unless absorb_errors(start)

      @window = Window.new(range: range, today: Time.current.in_time_zone(user.zone).to_date, first_day: start.first_day)
      count = CountService.new(user: user, window: window)
      count.call
      return unless absorb_errors(count)

      @counts = count.counts
      read_visits
      @links = top_links
      @shown = badges
    end

    def projects
      Progress::Projects.new(user.entries.publicly_visible.without_tooling_noise).all.map do |project|
        Page.new(key: project.repo, name: project.name, rank: project.rank)
      end
    end

    # Hosts grouped as the old analytics grouped them (Hacker News, GitHub,
    # Direct...), and the countries Cloudflare names, busiest first.
    def read_visits
      views = [ (user.profile_views if selected?(CountService::PAGE)), user.project_views.where(repo_name: selected.map(&:key)) ].compact
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

    def page_for(key)
      selected.find { |page| page.key == key }
    end

    def selected?(key)
      page_for(key).present?
    end

    def times
      window.days.first.in_time_zone(user.zone)..window.today.in_time_zone(user.zone).end_of_day
    end
  end
end
