require "rails_helper"
require "support/revenue_data"

RSpec.describe "Connecting a payment provider for MRR", type: :request do
  let(:user) { create(:user, username: "builder") }
  let(:page) { { data: [], has_more: false } }

  before do
    %i[products prices subscriptions invoices].each { |list| allow(StripeGateway).to receive(list).and_return(page) }
  end

  def revenue_section
    get "/settings", params: { tab: "integrations" }
    Nokogiri::HTML(response.body).at_css("section[aria-labelledby='revenue']")
  end

  it "asks a signed-out visitor to sign in" do
    post "/revenue_accounts", params: { provider: "stripe", api_key: "rk_test_ok" }

    expect(response).to redirect_to(root_path)
    expect(RevenueAccount.count).to eq(0)
  end

  context "when signed in" do
    before { sign_in_as(user) }

    it "offers Stripe's key field until it is connected" do
      expect(revenue_section.at_css("#stripe-connect input[type='password'][name='api_key']")).to be_present
      expect(revenue_section.text.squish).to include("Planned: Lemon Squeezy, Polar, Paddle and RevenueCat.")
    end

    it "connects Stripe and shows which key it holds, never the key" do
      post "/revenue_accounts", params: { provider: "stripe", api_key: " rk_test_abc123 " }

      expect(response).to redirect_to(settings_path(tab: "integrations", anchor: "revenue"))
      expect(flash[:notice]).to eq("Stripe connected.")
      section = revenue_section
      expect(section.text).to include("Connected · key ending c123")
      expect(section.to_html).not_to include("rk_test_abc123")
      expect(section.at_css("#stripe-connect")).to be_nil
    end

    it "says why a key is refused" do
      post "/revenue_accounts", params: { provider: "stripe", api_key: "sk_live_full" }

      expect(flash[:alert]).to start_with("That is a secret key")
      expect(user.revenue_accounts).to be_empty
    end

    it "says so when Stripe does not answer" do
      allow(StripeGateway).to receive(:products).and_raise(ApplicationGateway::ConnectionFailed)

      post "/revenue_accounts", params: { provider: "stripe", api_key: "rk_test_ok" }

      expect(flash[:alert]).to eq("Stripe did not answer. Please try again in a minute.")
    end

    it "disconnects Stripe, deleting the key" do
      account = user.revenue_accounts.create!(provider: "stripe", api_key: "rk_test_ok")

      delete "/revenue_accounts/#{account.id}"

      expect(response).to redirect_to(settings_path(tab: "integrations", anchor: "revenue"))
      expect(RevenueAccount.exists?(account.id)).to be(false)
    end

    it "never disconnects another builder's account" do
      other = create(:user).revenue_accounts.create!(provider: "stripe", api_key: "rk_test_other")

      delete "/revenue_accounts/#{other.id}"

      expect(response).to have_http_status(:not_found)
      expect(RevenueAccount.exists?(other.id)).to be(true)
    end
  end

  it "says since when it has not read a key that still works" do
    user.revenue_accounts.create!(provider: "stripe", api_key: "rk_test_ok", read_at: 4.days.ago, read_through: 4.days.ago.to_date)
    sign_in_as(user)

    get "/settings", params: { tab: "integrations" }

    expect(response.body).to include("Not read since #{4.days.ago.strftime('%b %-d')}")
    expect(Nokogiri::HTML(response.body).at_css("#stripe-connect")).to be_nil
  end

  it "says when Stripe refuses the key, offers to connect a new one, and takes the new one" do
    account = user.revenue_accounts.create!(provider: "stripe", api_key: "rk_test_gone", refused_at: Time.current)
    sign_in_as(user)

    section = revenue_section
    expect(section.text).to include("Stripe refuses the key ending gone")
    expect(section.at_css("#stripe-connect")).to be_present

    post "/revenue_accounts", params: { provider: "stripe", api_key: "rk_test_good" }

    expect(account.reload).to have_attributes(api_key: "rk_test_good", refused_at: nil)
  end

  it "disconnecting deletes the key and everything read with it, as the privacy page says" do
    account = user.revenue_accounts.create!(provider: "stripe", api_key: "rk_test_ok")
    product = account.revenue_products.create!(external_id: "prod_1", name: "Pro")
    revenue_day(product, day: Date.current, currency: "usd", mrr: 700, subscriptions: 1)
    sign_in_as(user)

    delete "/revenue_accounts/#{account.id}"

    expect([ RevenueAccount.count, RevenueProduct.count, RevenueDay.count, RevenueCustomerDay.count ]).to eq([ 0, 0, 0, 0 ])
  end

  it "links to what it reads and keeps from the form" do
    sign_in_as(user)

    expect(revenue_section.at_css("#stripe-connect a[href='/privacy#stripe']").text).to eq("What it reads and keeps")
  end
end
