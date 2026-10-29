class Entry < ApplicationRecord
  belongs_to :user
  has_many :entry_clicks, dependent: :destroy

  enum :entry_type, {
    shipped: "shipped",
    milestone: "milestone",
    note: "note",
    link: "link",
    repo_created: "repo_created",
    released: "released",
    posted: "posted"
  }

  # What a builder shipped and what they published, as the week card and the
  # progress section count them. A commit is neither, though it is stored as
  # shipped: only a Shipped entry the builder logged counts.
  SHIPPED_TYPES = %w[shipped milestone released].freeze
  PUBLISHED_TYPES = %w[posted link note].freeze

  enum :source, {
    github: "github",
    twitter: "twitter",
    manual: "manual"
  }

  validates :entry_type, presence: true
  validates :source, presence: true
  validates :title, presence: true
  validates :occurred_at, presence: true
  enum :visibility, {
    public_entry: "public",
    private_entry: "private"
  }, default: :public_entry

  validates :external_id, uniqueness: { scope: :user_id }, allow_nil: true

  # url is rendered into hrefs on the dashboard and redirected to by
  # EntryClicksController, so the scheme has to be safe at the source.
  validates :url, format: { with: %r{\Ahttps?://}i, message: "must start with http:// or https://" },
                  allow_blank: true

  # Blank form submissions arrive as "" — nilify so they don't leak into the
  # repo filter, which keys off `where.not(repo_name: nil)`.
  normalizes :repo_name, with: ->(value) { value.strip.presence }

  # A commit only on a branch other than the default shows while its builder
  # keeps branch commits on in Settings. Every page reads through here, so
  # turning the switch off hides them everywhere without touching a row.
  BRANCH_SWITCH_SQL = "entries.branch IS NULL OR EXISTS " \
                      "(SELECT 1 FROM users WHERE users.id = entries.user_id AND users.branch_commits)".freeze

  # A repo the builder hid takes everything tagged with it off their pages,
  # what they logged by hand too. The dashboard's switch marks only its synced
  # entries hidden.
  HIDDEN_REPO_SQL = "NOT EXISTS (SELECT 1 FROM github_repos WHERE github_repos.user_id = entries.user_id " \
                    "AND github_repos.full_name = entries.repo_name AND NOT github_repos.included)".freeze

  # True unless the entry's project is one whose builder hides its commits
  # from visitors (GithubRepo#hidden_numbers).
  HIDDEN_COMMITS_SQL = "NOT EXISTS (SELECT 1 FROM github_repos WHERE github_repos.user_id = entries.user_id " \
                       "AND github_repos.full_name = entries.repo_name AND github_repos.hidden_numbers @> '[\"commits\"]')".freeze

  scope :visible, -> { where(hidden: false).where(BRANCH_SWITCH_SQL) }
  scope :publicly_visible, -> { visible.where(visibility: :public_entry).where(HIDDEN_REPO_SQL) }
  scope :chronological, -> { order(occurred_at: :desc) }
  scope :pinned_entries, -> { where(pinned: true) }
  scope :commits, -> { where(source: :github, entry_type: :shipped) }
  # A project whose builder hides its commits shows visitors none of them:
  # no message, no count, no time taken from them. Its other entries stay
  # listed. Every commit is still synced and stored; the builder's own
  # views, the emails and the badge still count them.
  scope :without_hidden_commits, -> {
    where("NOT (entries.source = ? AND entries.entry_type = ?) OR #{HIDDEN_COMMITS_SQL}", sources[:github], entry_types[:shipped])
  }
  # where.not on two keys leaves out only the rows that match both: commits.
  scope :highlights, -> { where(entry_type: SHIPPED_TYPES + PUBLISHED_TYPES).where.not(source: :github, entry_type: :shipped) }

  # Case-insensitive match across the fields a builder would actually remember:
  # what it said, and which project it was.
  # RecapDraft::NOISE in Postgres syntax, so the public timeline can drop what
  # bots wrote without breaking pagination. A spec holds the two in agreement.
  TOOLING_NOISE_SQL = '^(merge (branch|pull request|remote|tag)\\M' \
                      '|(build|chore|fix|ci)\\(deps(-dev)?\\):' \
                      '|bump \\S+ from \\S+ to \\S+' \
                      '|update dependenc(y|ies)\\M' \
                      '|\\[dependabot\\])'.freeze

  # Only synced commits are ever filtered. Anything a person typed stays.
  scope :without_tooling_noise, -> {
    where.not("entries.source = ? AND entries.title ~* ?", sources[:github], TOOLING_NOISE_SQL)
  }

  scope :search, ->(term) {
    pattern = "%#{sanitize_sql_like(term.to_s.strip)}%"
    where("title ILIKE :q OR body ILIKE :q OR repo_name ILIKE :q", q: pattern)
  }

  # The feed: every builder's public work but the owner's, so it shows the
  # others; merges and dependency bumps left out, as on every page.
  scope :on_feed, -> { publicly_visible.without_tooling_noise.joins(:user).merge(User.active.not_owner) }

  # A few of the latest feed entries, newest first, at most per_builder from
  # any one builder, so one busy day does not fill them all.
  def self.lately(count: 12, per_builder: 3)
    on_feed.includes(:user).chronological.limit(count * 5).group_by(&:user_id).values
           .flat_map { |entries| entries.first(per_builder) }.sort_by(&:occurred_at).reverse.first(count)
  end

  # What a builder's pages read: their public entries, tooling noise left
  # out. reveal: one repo they hid, shown anyway as its project page would
  # show it, for the builder's own look at that page; its synced entries
  # count though the switch marked them hidden.
  def self.on_page(reveal: nil)
    shown = publicly_visible
    if reveal
      shown = shown.or(where(repo_name: reveal, visibility: :public_entry).where(BRANCH_SWITCH_SQL)
                         .where("entries.hidden = false OR entries.source = ?", sources[:github]))
    end
    shown.without_tooling_noise
  end

  # The repos these entries came from, for a repo filter.
  def self.repo_names
    where.not(repo_name: nil).distinct.order(:repo_name).pluck(:repo_name)
  end

  def commit?
    github? && shipped?
  end

  def highlight?
    !commit? && (SHIPPED_TYPES + PUBLISHED_TYPES).include?(entry_type)
  end
end
