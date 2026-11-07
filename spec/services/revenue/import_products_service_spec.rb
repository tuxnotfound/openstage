require "rails_helper"

RSpec.describe Revenue::ImportProductsService do
  let(:user) { create(:user) }
  let(:account) { user.revenue_accounts.create!(provider: "stripe", api_key: "rk_test_ok") }
  let(:repo) { create(:github_repo, user: user, name: "shipnote") }

  def product(id, name, active: true)
    { id: id, object: "product", name: name, active: active }
  end

  it "reads every page of products, archived ones too" do
    allow(StripeGateway).to receive(:products).with("rk_test_ok", limit: 100)
                                              .and_return(data: [ product("prod_1", "Shipnote Pro") ], has_more: true)
    allow(StripeGateway).to receive(:products).with("rk_test_ok", limit: 100, starting_after: "prod_1")
                                              .and_return(data: [ product("prod_2", "Old plan", active: false) ], has_more: false)

    travel_to(Time.utc(2026, 11, 7, 10)) { described_class.new(account: account).call! }

    expect(account.revenue_products.order(:external_id).pluck(:external_id, :name, :active))
      .to eq([ [ "prod_1", "Shipnote Pro", true ], [ "prod_2", "Old plan", false ] ])
    expect(account.reload.products_read_at).to eq(Time.utc(2026, 11, 7, 10))
  end

  it "follows Stripe's names and keeps the project a product counts for" do
    account.revenue_products.create!(external_id: "prod_1", name: "Pro", github_repo: repo)
    allow(StripeGateway).to receive(:products).and_return(data: [ product("prod_1", "Shipnote Pro") ], has_more: false)

    described_class.new(account: account).call!

    expect(account.revenue_products.sole).to have_attributes(name: "Shipnote Pro", github_repo: repo)
  end

  it "drops a product gone from Stripe" do
    account.revenue_products.create!(external_id: "prod_gone", name: "Gone")
    allow(StripeGateway).to receive(:products).and_return(data: [], has_more: false)

    described_class.new(account: account).call!

    expect(account.revenue_products.reload).to be_empty
  end
end
