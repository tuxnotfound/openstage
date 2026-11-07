require "rails_helper"

RSpec.describe Revenue::CountProductService do
  let(:user) { create(:user, pro: true) }
  let(:account) { user.revenue_accounts.create!(provider: "stripe", api_key: "rk_test_ok") }
  let(:shipnote) { create(:github_repo, user: user, name: "shipnote") }
  let(:tidepool) { create(:github_repo, user: user, name: "tidepool") }
  let(:monthly) { account.revenue_products.create!(external_id: "prod_m", name: "Shipnote monthly") }
  let(:yearly) { account.revenue_products.create!(external_id: "prod_y", name: "Shipnote yearly") }

  def count(repo, product, counted = true)
    described_class.new(repo: repo, product: product, counted: counted)
  end

  it "counts a product for a project, and keeps when it was first given one" do
    set_up = Time.utc(2026, 11, 7, 9)
    travel_to(set_up) { count(shipnote, monthly).call! }
    count(shipnote, yearly).call!
    count(shipnote, monthly, false).call!

    expect([ monthly.reload.github_repo, yearly.reload.github_repo ]).to eq([ nil, shipnote ])
    expect(shipnote.reload.revenue_set_up_at).to eq(set_up)
  end

  it "refuses a product that counts for another project" do
    count(tidepool, monthly).call!
    service = count(shipnote, monthly)

    expect(service.call).to be(false)
    expect(service.errors.full_messages).to eq([ "Shipnote monthly counts for tidepool. Switch it off there first." ])
    expect(monthly.reload.github_repo).to eq(tidepool)
  end

  it "refuses another builder's product" do
    other = create(:user).revenue_accounts.create!(provider: "stripe", api_key: "rk_test_other")
    service = count(shipnote, other.revenue_products.create!(external_id: "prod_x", name: "Theirs"))

    expect(service.call).to be(false)
    expect(service.errors.full_messages).to eq([ "That product is not in your Stripe account." ])
  end

  context "on Free" do
    let(:user) { create(:user, pro: false) }

    it "counts the first project given a product, for life" do
      count(shipnote, monthly).call!
      count(shipnote, monthly, false).call!
      service = count(tidepool, yearly)

      expect(service.call).to be(false)
      expect(service.errors.full_messages).to eq([ "Free counts MRR for one project, shipnote. Go Pro to count it for every project." ])
      expect(count(shipnote, yearly).call).to be(true)
    end

    it "lets a product go from any project" do
      user.update!(pro: true)
      count(shipnote, monthly).call!
      count(tidepool, yearly).call!
      user.update!(pro: false)

      expect(count(tidepool, yearly, false).call).to be(true)
    end
  end

  it "counts every project on Pro" do
    count(shipnote, monthly).call!

    expect(count(tidepool, yearly).call).to be(true)
  end
end
