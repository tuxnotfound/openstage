require "rails_helper"

RSpec.describe "A project's Revenue (MRR) row", type: :request do
  let(:user) { create(:user, username: "builder", pro: true) }
  let!(:shipnote) { create(:github_repo, user: user, name: "shipnote", full_name: "builder/shipnote") }
  let!(:tidepool) { create(:github_repo, user: user, name: "tidepool", full_name: "builder/tidepool") }

  before { sign_in_as(user) }

  def connect
    user.revenue_accounts.create!(provider: "stripe", api_key: "rk_test_ok", products_read_at: Time.current)
  end

  def row(repo = shipnote)
    get "/projects/#{repo.id}/edit", params: { revenue: "open" }
    Nokogiri::HTML(response.body).at_css("#revenue")
  end

  it "leads to Integrations until Stripe is connected" do
    expect(row.at_css("a[href='/settings?tab=integrations#revenue']").text).to eq("Connect Stripe")
    expect(row.text).to include("From Stripe, once you connect it on Integrations.")
  end

  it "lists the account's products with a switch each, and locks one another project counts" do
    account = connect
    account.revenue_products.create!(external_id: "prod_m", name: "Shipnote monthly")
    account.revenue_products.create!(external_id: "prod_t", name: "Tidepool starter", github_repo: tidepool)

    products = row.css("#revenue-products .os-row")
    expect(products.map { |product| product.at_css(".font-semibold").text }).to eq([ "Shipnote monthly", "Tidepool starter" ])
    expect(products.last.text).to include("Counts for tidepool")
    expect(products.last.at_css("button[role='switch']")["disabled"]).to be_present
    expect(row.text).to include("No Stripe product counts for it yet.")
  end

  it "counts a product for the project and comes back with the products open" do
    product = connect.revenue_products.create!(external_id: "prod_m", name: "Shipnote monthly")

    patch "/projects/#{shipnote.id}/revenue_products/#{product.id}", params: { counted: "true" }

    expect(response).to redirect_to(edit_project_path(shipnote, revenue: "open", anchor: "revenue"))
    expect(product.reload.github_repo).to eq(shipnote)
    expect(row.text).to include("Verified with Stripe, from Shipnote monthly.")
  end

  it "says the products are on their way until Stripe's are read" do
    connect.update!(products_read_at: nil)

    expect(row.text).to include("Reading your products from Stripe. Open this again in a minute.")
  end

  it "never counts another builder's product" do
    other = create(:user).revenue_accounts.create!(provider: "stripe", api_key: "rk_test_other")
    product = other.revenue_products.create!(external_id: "prod_x", name: "Theirs")

    patch "/projects/#{shipnote.id}/revenue_products/#{product.id}", params: { counted: "true" }

    expect(response).to have_http_status(:not_found)
    expect(product.reload.github_repo).to be_nil
  end

  context "on Free" do
    let(:user) { create(:user, username: "builder", pro: false) }

    it "says only its builder sees it, and that Free counts one project" do
      connect.revenue_products.create!(external_id: "prod_m", name: "Shipnote monthly", github_repo: shipnote)
      shipnote.update!(revenue_set_up_at: Time.current)

      expect(row.text).to include("Verified with Stripe, from Shipnote monthly. Only you see it: Pro shows it on its page.", "Only you")
      expect(row.at_css("[data-free-notice]").text.squish).to start_with("Free counts MRR for one project only")
    end

    it "keeps only Go Pro on another project, and says why" do
      connect
      shipnote.update!(revenue_set_up_at: Time.current)

      tidepool_row = row(tidepool)
      expect(tidepool_row.text).to include("You already count MRR on shipnote, the one project Free counts.")
      expect(tidepool_row.at_css("a[href='/pricing']").text).to eq("Go Pro")
      expect(tidepool_row.at_css("#revenue-products")).to be_nil
    end

    it "refuses a second project with Free's reason" do
      product = connect.revenue_products.create!(external_id: "prod_t", name: "Tidepool starter")
      shipnote.update!(revenue_set_up_at: Time.current)

      patch "/projects/#{tidepool.id}/revenue_products/#{product.id}", params: { counted: "true" }

      expect(flash[:alert]).to eq("Free counts MRR for one project, shipnote. Go Pro to count it for every project.")
      expect(product.reload.github_repo).to be_nil
    end
  end
end
