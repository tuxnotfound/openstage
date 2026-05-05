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

  scope :visible, -> { where(hidden: false) }
  scope :publicly_visible, -> { visible.where(visibility: :public_entry) }
  scope :chronological, -> { order(occurred_at: :desc) }
  scope :pinned_entries, -> { where(pinned: true) }
end
