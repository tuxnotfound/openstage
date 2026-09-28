# A reader who asked for a builder's updates by email. Double opt-in: a row is
# created on the form, and counts only once the token in the confirmation mail
# has been clicked. Unsubscribe deletes the row; there is no reason to keep an
# address someone asked us to forget.
class Subscription < ApplicationRecord
  belongs_to :user

  has_secure_token :token

  # Enough time between two confirmation mails to the same address.
  RESEND_AFTER = 10.minutes

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: "does not look like an email address" },
                    length: { maximum: 254 },
                    uniqueness: { scope: :user_id }

  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :pending,   -> { where(confirmed_at: nil) }

  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    update!(confirmed_at: Time.current) unless confirmed?
  end

  def confirmation_due?
    !confirmed? && (confirmation_sent_at.nil? || confirmation_sent_at < RESEND_AFTER.ago)
  end
end
