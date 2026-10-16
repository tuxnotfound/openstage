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

  scope :visible, -> { where(hidden: false).where(BRANCH_SWITCH_SQL) }
  scope :publicly_visible, -> { visible.where(visibility: :public_entry) }
  scope :chronological, -> { order(occurred_at: :desc) }
  scope :pinned_entries, -> { where(pinned: true) }
  scope :commits, -> { where(source: :github, entry_type: :shipped) }
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
