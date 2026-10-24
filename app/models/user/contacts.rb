class User
  # A builder's email and X account, and whether their page shows each. Both
  # stay hidden until the builder turns them on. The email is also where the
  # builder's own mail goes.
  module Contacts
    extend ActiveSupport::Concern

    # How people paste an X account: "@name", "x.com/name" or the whole link.
    X_PREFIX = %r{\A(?:https?://)?(?:www\.)?(?:x|twitter)\.com/|\A@}i

    included do
      normalizes :email, with: ->(value) { value.strip.presence }
      normalizes :x_username, with: ->(value) { value.strip.sub(X_PREFIX, "").presence }

      validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "is not an email address" }, allow_blank: true
      validates :x_username, format: { with: /\A[A-Za-z0-9_]{1,15}\z/, message: "takes letters, numbers and underscores, up to 15" },
                             allow_blank: true
    end

    # What the builder's page shows: nil unless they chose to show it.
    def public_email
      email if show_email?
    end

    def public_x_username
      x_username if show_x_username?
    end
  end
end
