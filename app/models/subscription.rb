# A reader who asked for a builder's updates by email: the whole page, or one
# project (github_repo). Double opt-in: a row is created on the form, and
# counts only once the token in the confirmation mail has been clicked.
# Unsubscribe deletes the row; there is no reason to keep an address someone
# asked us to forget.
class Subscription < ApplicationRecord
  belongs_to :user
  belongs_to :github_repo, optional: true

  has_secure_token :token

  # Enough time between two confirmation mails to the same address.
  RESEND_AFTER = 10.minutes

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: "does not look like an email address" },
                    length: { maximum: 254 },
                    uniqueness: { scope: [ :user_id, :github_repo_id ] }
  validate :project_is_the_builders

  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :pending,   -> { where(confirmed_at: nil) }
  scope :whole_page, -> { where(github_repo_id: nil) }
  scope :projects,   -> { where.not(github_repo_id: nil) }

  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    update!(confirmed_at: Time.current) unless confirmed?
  end

  def confirmation_due?
    !confirmed? && (confirmation_sent_at.nil? || confirmation_sent_at < RESEND_AFTER.ago)
  end

  # What the reader follows, in words: the project's name, or the builder's.
  def followed_name
    github_repo ? github_repo.name : user.display_name
  end

  private

  def project_is_the_builders
    errors.add(:github_repo, "is not on this builder's page") if github_repo && github_repo.user_id != user_id
  end
end
