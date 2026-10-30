module SiteVisits
  # The busiest values of one kind on some projects' websites over some days
  # (SiteVisitCount): pages by page views; sources, ref tags and countries
  # by visitors, each counted once a day. A source is named as Openstage's
  # own Sources panel names it (ReferrerClassifier.label) and hosts of one
  # name count together, so sources are cut after naming; the database cuts
  # the other kinds. Sources, ref tags and countries add up across sites,
  # but a path means something only on its own site, so a page is ranked
  # per project.
  class RankService < ApplicationService
    SUMMED = "SUM(site_visit_counts.count) AS summed".freeze
    # Every value's count, beside each grouped row.
    TOTAL = "CAST(SUM(SUM(site_visit_counts.count)) OVER () AS bigint) AS total".freeze
    # Whether pages of more than one project count, beside each page's row.
    SEVERAL = "MIN(site_visit_counts.github_repo_id) OVER () <> MAX(site_visit_counts.github_repo_id) OVER () AS several".freeze
    # The busiest first, then by value; the cap's Other row after the rest,
    # so it takes no place in the top.
    ORDER = "site_visit_counts.value = ?, SUM(site_visit_counts.count) DESC, site_visit_counts.value".freeze

    # repos: GithubRepos, their ids or a relation of them; days: a range of
    # days, beginless for every day up to its end, nil for every day; kind:
    # one of SiteVisitCount::KINDS; top: how many values to keep.
    attr_accessor :repos, :days, :kind, :top
    # ranked: [[label, count]], the busiest first, then by label, at most
    # top of them, with "Direct" among sources; a page's also names its
    # project while pages of several projects count, else nil: [[path,
    # count, project]]. other: what the list leaves out, the values past the
    # top and the cap's Other row, 0 without any, so the list and other add
    # up to the total.
    attr_reader :ranked, :other

    validates :kind, inclusion: { in: SiteVisitCount::KINDS }
    validates :top, numericality: { only_integer: true, greater_than: 0 }

    private

    def execute
      counts = SiteVisitCount.where(github_repo_id: repos, kind: kind)
      counts = counts.where(day: days) if days
      @ranked, total = rank(counts)
      @other = total - ranked.sum { |_label, count| count }
    end

    def rank(counts)
      case kind
      when "source" then by_name(counts)
      when "page" then by_page(counts)
      else by_value(counts)
      end
    end

    # The top and the total of every value.
    def by_name(counts)
      sums = counts.group(:value).sum(:count)
      named = sums.except(SiteVisitCount::OTHER).each_with_object(Hash.new(0)) { |(host, count), all| all[name_of(host)] += count }
      [ named.sort_by { |label, count| [ -count, label ] }.first(top), sums.values.sum ]
    end

    # Direct is stored as DIRECT, a value no host can take.
    def name_of(host)
      ReferrerClassifier.label(host == SiteVisitCount::DIRECT ? nil : host)
    end

    # The top and the total of every value, in one grouped query.
    def by_value(counts)
      rows = counts.group(:value).order(order).limit(top).pluck(:value, Arel.sql(SUMMED), Arel.sql(TOTAL))
      [ rows.filter_map { |value, count, _| [ value, count ] unless value == SiteVisitCount::OTHER }, rows.first&.last.to_i ]
    end

    # As by_value, a row per project and path, each project's cap row in
    # the total.
    def by_page(counts)
      rows = counts.joins(:github_repo).group(:github_repo_id, "github_repos.name", :value).order(order, "github_repos.name").limit(top)
                   .pluck(:value, Arel.sql(SUMMED), "github_repos.name", Arel.sql(SEVERAL), Arel.sql(TOTAL))
      ranked = rows.filter_map { |path, count, name, several, _| [ path, count, (name if several) ] unless path == SiteVisitCount::OTHER }
      [ ranked, rows.first&.last.to_i ]
    end

    def order
      Arel.sql(SiteVisitCount.sanitize_sql_array([ ORDER, SiteVisitCount::OTHER ]))
    end
  end
end
