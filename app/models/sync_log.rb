class SyncLog < ApplicationRecord
  belongs_to :user

  enum :source, { github: "github", twitter: "twitter" }
  enum :status, { running: "running", success: "success", failed: "failed" }

  # GithubSyncJob's note when GitHub turns down the builder's token. The
  # dashboard then offers to reconnect instead of syncing.
  TOKEN_REJECTED = "GitHub no longer accepts Openstage's access to your account. Reconnect GitHub to resume syncing.".freeze

  validates :source, presence: true
  validates :status, presence: true
  validates :ran_at, presence: true

  def token_rejected?
    failed? && error_message == TOKEN_REJECTED
  end
end
