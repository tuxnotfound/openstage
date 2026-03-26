class SyncLog < ApplicationRecord
  belongs_to :user

  enum :source, { github: "github", twitter: "twitter" }
  enum :status, { running: "running", success: "success", failed: "failed" }

  validates :source, presence: true
  validates :status, presence: true
  validates :ran_at, presence: true
end
