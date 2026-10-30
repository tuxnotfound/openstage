module SiteVisits
  # The busiest values of one kind on some projects' websites over some days
  # (SiteVisitCount): pages by page views; sources, ref tags and countries
  # by visitors, each counted once a day, by their first view. A source is
  # named as Openstage's own Sources panel names it (ReferrerClassifier.label)
  # and hosts of one name count together, so sources are cut after naming;
  # the database cuts the other kinds.
  class RankService < ApplicationService
    # repos: GithubRepos, their ids or a relation of them; days: a range of
    # days, beginless for every day up to its end, nil for every day; kind:
    # one of SiteVisitCount::KINDS; top: how many values to keep.
    attr_accessor :repos, :days, :kind, :top
    # ranked: [[label, count]], the busiest first, then by label, at most
    # top of them, with "Direct" among sources; other: what went to the cap's
    # Other row, 0 without one.
    attr_reader :ranked, :other

    validates :kind, inclusion: { in: SiteVisitCount::KINDS }
    validates :top, numericality: { only_integer: true, greater_than: 0 }

    private

    def execute
      counts = SiteVisitCount.where(github_repo_id: repos, kind: kind)
      counts = counts.where(day: days) if days
      @ranked, @other = kind == "source" ? by_name(counts) : by_value(counts)
    end

    def by_name(counts)
      sums = counts.group(:value).sum(:count)
      other = sums.delete(SiteVisitCount::OTHER).to_i
      named = sums.each_with_object(Hash.new(0)) { |(host, count), all| all[name_of(host)] += count }
      [ named.sort_by { |label, count| [ -count, label ] }.first(top), other ]
    end

    # Direct is stored as DIRECT, a value no host can take.
    def name_of(host)
      ReferrerClassifier.label(host == SiteVisitCount::DIRECT ? nil : host)
    end

    # One grouped query: the Other row first when there is one, then the
    # busiest values.
    def by_value(counts)
      order = SiteVisitCount.sanitize_sql_array([ "site_visit_counts.value = ? DESC, SUM(site_visit_counts.count) DESC, site_visit_counts.value",
                                                  SiteVisitCount::OTHER ])
      sums = counts.group(:value).order(Arel.sql(order)).limit(top + 1).sum(:count)
      other = sums.delete(SiteVisitCount::OTHER).to_i
      [ sums.to_a.first(top), other ]
    end
  end
end
