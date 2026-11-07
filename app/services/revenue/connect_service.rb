module Revenue
  # Connects a builder's Stripe account, so their projects can show MRR from
  # it. Only a restricted key is taken: a secret key can also charge and
  # refund. Before it is kept, it must read everything MRR is made of, and a
  # key that misses a read is refused, naming it. Outside production a test
  # key works too. Connecting again replaces the key. Its products are read
  # next, in the background.
  class ConnectService < ApplicationService
    # What the key must read, as Stripe's key settings name them.
    READS = %w[Products Prices Subscriptions Invoices].freeze

    attr_accessor :user, :provider, :api_key
    attr_reader :account

    validates :user, presence: true
    validates :provider, inclusion: { in: RevenueAccount::PROVIDERS }
    validate :a_restricted_key

    private

    def execute
      unread = unread_resources
      return if errors.any?
      return refuse(unread) if unread.any?

      @account = user.revenue_accounts.find_or_initialize_by(provider: provider)
      @account.update(api_key: api_key)
      return unless absorb_errors(@account)

      after_commit { ImportRevenueProductsJob.perform_later(@account.id) }
    end

    # The reads the key lacks, a 403 each. A 401 is a key Stripe does not
    # know, and ends the check.
    def unread_resources
      READS.each_with_object([]) do |resource, unread|
        read(resource)
      rescue ApplicationGateway::Unauthorized => error
        next unread << resource if error.status == 403

        errors.add(:base, "Stripe does not know this key. Copy it again from Stripe's API keys page.")
        break unread
      end
    end

    def read(resource)
      case resource
      when "Products" then StripeGateway.products(api_key, limit: 1)
      when "Prices" then StripeGateway.prices(api_key, limit: 1)
      when "Subscriptions" then StripeGateway.subscriptions(api_key, limit: 1)
      when "Invoices" then StripeGateway.invoices(api_key, limit: 1)
      end
    end

    def refuse(unread)
      errors.add(:base, "This key cannot read #{listed(unread)}. In Stripe, give it Read on #{listed(READS)}.")
    end

    def listed(resources)
      resources.to_sentence(last_word_connector: " and ")
    end

    def a_restricted_key
      if api_key.to_s.start_with?("sk_")
        errors.add(:base, "That is a secret key, which can also charge and refund. Create a restricted key that only reads.")
      elsif !api_key.to_s.match?(restricted_key)
        errors.add(:base, "Paste a restricted key from Stripe: it starts with #{Rails.env.production? ? 'rk_live_' : 'rk_'}.")
      end
    end

    def restricted_key
      Rails.env.production? ? /\Ark_live_\w+\z/ : /\Ark_(live|test)_\w+\z/
    end
  end
end
