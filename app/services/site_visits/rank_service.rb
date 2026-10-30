module SiteVisits
  # The busiest values of one kind on some projects' websites over some days
  # (SiteVisitCount): pages by page views; sources, ref tags and countries
  # by visitors, each counted once a day, by their first view. A source is
  # named as Openstage's own Sources panel names it (ReferrerClassifier.label)
  # and hosts of one name count together, so sources are cut after naming;
  # the database cuts the other kinds.
  class RankService < ApplicationService
    # Every value's count, beside each grouped row.
    TOTAL = "CAST(SUM(SUM(site_visit_counts.count)) OVER () AS bigint) AS total".freeze

    # repos: GithubRepos, their ids or a relation of them; days: a range of
    # days, beginless for every day up to its end, nil for every day; kind:
    # one of SiteVisitCount::KINDS; top: how many values to keep.
    attr_accessor :repos, :days, :kind, :top
    # ranked: [[label, count]], the busiest first, then by label, at most
    # top of them, with "Direct" among sources; other: what the list leaves
    # out, the values past the top and the cap's Other row, 0 without any,
    # so the list and other add up to the total.
    attr_reader :ranked, :other

    validates :kind, inclusion: { in: SiteVisitCount::KINDS }
    validates :top, numericality: { only_integer: true, greater_than: 0 }

    private

    def execute
      counts = SiteVisitCount.where(github_repo_id: repos, kind: kind)
      counts = counts.where(day: days) if days
      @ranked, total = kind == "source" ? by_name(counts) : by_value(counts)
      @other = total - ranked.sum { |_label, count| count }
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

    # The top and the total of every value, in one grouped query: the total
    # sits beside each row, and the cap's Other row sorts after the rest, so
    # it takes no place in the top.
    def by_value(counts)
      order = SiteVisitCount.sanitize_sql_array([ "site_visit_counts.value = ?, SUM(site_visit_counts.count) DESC, site_visit_counts.value",
                                                  SiteVisitCount::OTHER ])
      rows = counts.group(:value).order(Arel.sql(order)).limit(top)
                   .pluck(:value, Arel.sql("SUM(site_visit_counts.count) AS summed"), Arel.sql(TOTAL))
      [ rows.filter_map { |value, count, _| [ value, count ] unless value == SiteVisitCount::OTHER }, rows.first&.last.to_i ]
    end
  end
end
