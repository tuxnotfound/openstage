# One day's count of one value on a project's website, in the builder's
# zone: a page's views; or visitors by the site they came from, their ref
# tag or their country, each counted once a day, by their first view
# (SiteVisits::PageView). Only these totals are kept.
class SiteVisitCount < ApplicationRecord
  KINDS = %w[page source ref country].freeze
  # The script's token is public, so a flood of made-up values could grow a
  # day without end: past these, a new value counts as OTHER, and the day's
  # totals stay right. Countries are two letters, a few hundred at most.
  CAPS = { "page" => 100, "source" => 50, "ref" => 50 }.freeze
  # No path (it starts with "/"), host, tag or country code can take these.
  DIRECT = "(direct)".freeze
  OTHER = "(other)".freeze

  belongs_to :github_repo

  validates :kind, inclusion: { in: KINDS }

  # Adds one to each value's count for a project's day, by kind, in one
  # statement. A value the day has not counted yet counts as OTHER once its
  # kind has CAPS of them; two values new at the same instant can both take
  # the last place, so a day can pass a cap by a few.
  def self.add(repo_id, day, values)
    return if values.empty?

    caps = values.keys.map { |kind| CAPS[kind] }
    connection.exec_update(sanitize_sql_array([ ADD, { repo: repo_id, day: day, other: OTHER, kinds: values.keys, values: values.values, caps: caps } ]),
                           "SiteVisitCount Add")
  end

  ADD = <<~SQL.freeze
    INSERT INTO site_visit_counts (github_repo_id, kind, day, value, count)
    SELECT :repo, added.kind, CAST(:day AS date),
           CASE WHEN added.cap IS NULL
                  OR EXISTS (SELECT 1 FROM site_visit_counts kept
                             WHERE kept.github_repo_id = :repo AND kept.kind = added.kind AND kept.day = :day AND kept.value = added.value)
                  OR (SELECT COUNT(*) FROM site_visit_counts kept
                      WHERE kept.github_repo_id = :repo AND kept.kind = added.kind AND kept.day = :day AND kept.value <> :other) < added.cap
                THEN added.value ELSE :other END,
           1
    FROM unnest(ARRAY[:kinds]::varchar[], ARRAY[:values]::varchar[], ARRAY[:caps]::integer[]) AS added (kind, value, cap)
    ON CONFLICT (github_repo_id, kind, day, value) DO UPDATE SET count = site_visit_counts.count + 1
  SQL
  private_constant :ADD
end
