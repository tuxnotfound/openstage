module Analytics
  # Analytics' panels of the builder's pages on Openstage, for the pages in
  # view over some days: where their views came from, the countries Cloudflare
  # names, the links followed and where the badge and embed showed.
  class GatherPagesService < ApplicationService
    Link = Data.define(:title, :page, :count)

    # pages: the Progress::Rows in view; split: the Split of the days.
    attr_accessor :user, :pages, :split
    # sources and countries: [[label, count]], the busiest first, then Other
    # while the list leaves anything out; links: the Links followed, the
    # busiest first; badges: [kind, times shown, sites] for the README badge
    # and the embed.
    attr_reader :sources, :countries, :links, :badges

    validates :user, :split, presence: true

    private

    def execute
      read_visits
      @links = top_links
      @badges = badges_seen
    end

    # Sources named as the website panels name them (Hacker News, Direct,
    # indiehackers.com...), and the countries Cloudflare names, busiest
    # first, then Other.
    def read_visits
      views = [ (user.profile_views if page_for(CountService::PAGE)), user.project_views.where(repo_name: pages.map(&:key)) ].compact
      views = views.map { |scope| split.raw(scope, :viewed_at) }
      sources = counted("source").transform_keys { |host| named(host) }.to_a + views.flat_map { |scope| scope.group(:referrer).count.to_a }
      @sources = ranked(tally(sources) { |host| source_label(host) }, ReportService::TOP)
      countries = views.flat_map { |scope| scope.where.not(country: [ nil, "", *SiteVisits::PageView::NO_COUNTRY ]).group(:country).count.to_a }
      @countries = ranked(tally(counted("country").to_a + countries, &:itself), ReportService::TOP_COUNTRIES)
    end

    def counted(kind)
      split.totals(user.page_counts.where(kind: kind, page: pages.map(&:key))).group(:value).sum(:count)
    end

    # What the totals call a view with no referrer, as the raw row has it.
    def named(host)
      host unless host == SiteVisitCount::DIRECT
    end

    def tally(pairs)
      pairs.each_with_object(Hash.new(0)) { |(key, count), sums| sums[yield(key)] += count }.sort_by { |key, count| [ -count, key ] }
    end

    # A host that names no site, an address or a machine on someone's network
    # (pedros-macbook-pro.local), goes in Other: the website panels never
    # show one, because the script does not keep it.
    def source_label(host)
      host.blank? || SiteVisits::PageView.site?(host) ? ReferrerClassifier.label(host) : ReportService::OTHER
    end

    # The busiest, at most top of them, then Other while the list leaves
    # anything out, the hosts source_label sends there included.
    def ranked(sorted, top)
      shown = sorted.reject { |label, _count| label == ReportService::OTHER }.first(top)
      rest = sorted.sum(&:last) - shown.sum(&:last)
      rest.positive? ? shown + [ [ ReportService::OTHER, rest ] ] : shown
    end

    # Entry links and project buttons, together, busiest first.
    def top_links
      (entry_links + button_links).sort_by { |link| [ -link.count, link.title ] }.first(ReportService::TOP)
    end

    def entry_links
      clicks = sum(split.totals(user.entry_click_days).group(:entry_id).sum(:clicks),
                   split.raw(user.entry_clicks.joins(:entry), :clicked_at).group(:entry_id).count)
      user.entries.where(id: clicks.keys).filter_map do |entry|
        page = page_for(entry.repo_name || CountService::PAGE)
        Link.new(title: entry.title, page: page, count: clicks[entry.id]) if page
      end
    end

    def button_links
      repos = user.github_repos.index_by(&:full_name)
      button_clicks.filter_map do |(repo, kind), count|
        page = page_for(repo)
        host = host_of(repos[repo]&.outbound_url("visit"))
        title = kind == "visit" ? "Visit #{host || 'the website'}" : "View on GitHub"
        Link.new(title: title, page: page, count: count) if page
      end
    end

    def button_clicks
      sum(split.totals(user.page_counts.buttons).group(:page, :value).sum(:count),
          split.raw(user.project_clicks, :clicked_at).group(:repo_name, :kind).count)
    end

    # [kind, times shown, sites]: a view with no referrer shows on no site.
    def badges_seen
      seen = sum(split.totals(user.page_counts.where(kind: %w[badge embed])).group(:kind, :value).sum(:count),
                 split.raw(user.badge_impressions, :viewed_at).group(:kind, :referrer).count)
      %w[badge embed].map do |kind|
        sites = seen.select { |(shown, _site), _count| shown == kind }
        [ kind, sites.values.sum, sites.keys.filter_map { |_shown, site| named(site) }.uniq.size ]
      end
    end

    def sum(totals, raw)
      totals.merge(raw) { |_key, one, other| one + other }
    end

    def host_of(url)
      URI(url).host if url
    rescue URI::InvalidURIError
      nil
    end

    def page_for(key)
      pages.find { |row| row.key == key }
    end
  end
end
