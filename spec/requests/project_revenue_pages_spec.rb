require "rails_helper"

RSpec.describe "MRR on the chart pages", type: :request do
  let(:user) { create(:user, username: "builder", pro: true) }
  let!(:repo) { create(:github_repo, user: user, name: "shipnote", full_name: "builder/shipnote") }
  let(:today) { Time.current.in_time_zone(user.zone).to_date }

  before do
    create(:entry, user: user, repo_name: repo.full_name, occurred_at: 2.days.ago)
    account = user.revenue_accounts.create!(provider: "stripe", api_key: "rk_test_ok", read_at: Time.current)
    product = account.revenue_products.create!(external_id: "prod_m", name: "Monthly", github_repo: repo)
    product.revenue_days.create!(day: today - 10, currency: "usd", mrr: 210_000, subscriptions: 100)
    product.revenue_days.create!(day: today, currency: "usd", mrr: 421_000, subscriptions: 230)
  end

  def view
    get "/api/progress/builder", params: { project: repo.full_name, range: "30d" }
    JSON.parse(response.body)
  end

  def figure
    Nokogiri::HTML(response.body).at_css("[data-revenue]")
  end

  def response_status_of_view
    view
    response.status
  end

  def number(key)
    view["numbers"].find { |each| each["key"] == key }
  end

  it "shows MRR and paying customers on Pro, drawing MRR by default" do
    expect(number("mrr")["value"]).to eq("$4,210")
    expect(number("customers")["value"]).to eq("230")
    expect(view["drawn"]).to include("mrr")
  end

  it "leaves them off on Free, which shows them only on the project's own view" do
    user.update!(pro: false)

    expect(number("mrr")).to be_nil
    expect(number("customers")).to be_nil
  end

  it "hides each one its builder switched off, and the other stays" do
    repo.update!(hidden_numbers: %w[mrr])

    expect(number("mrr")).to be_nil
    expect(number("customers")["value"]).to eq("230")
  end

  it "knows a project with products but no sale counts nothing yet" do
    RevenueDay.delete_all

    expect(number("mrr")).to be_nil
  end

  it "takes them off the pages when Stripe refuses the key, past the page's cache" do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    expect(number("mrr")["value"]).to eq("$4,210")

    user.revenue_accounts.first.update!(refused_at: Time.current)

    expect(number("mrr")).to be_nil
    get "/builder/shipnote"
    expect(figure).to be_nil
  end

  describe "the project's page" do
    it "says its MRR and paying customers under its description, verified" do
      get "/builder/shipnote"

      expect(figure.at_css(".os-num").text).to eq("$4,210")
      expect(figure.text.squish).to eq("$4,210 MRR · 230 paying customers · Verified with Stripe")
    end

    it "says only paying customers for a builder who hides MRR" do
      repo.update!(hidden_numbers: %w[mrr])

      get "/builder/shipnote"

      expect(figure.text.squish).to eq("230 paying customers · Verified with Stripe")
    end

    it "says one paying customer, as one" do
      RevenueDay.where(day: today).update_all(subscriptions: 1)
      repo.update!(hidden_numbers: %w[mrr])

      get "/builder/shipnote"

      expect(figure.text.squish).to eq("1 paying customer · Verified with Stripe")
    end

    it "says nothing on Free, nor for a builder who hides both" do
      user.update!(pro: false)
      get "/builder/shipnote"
      expect(figure).to be_nil

      user.update!(pro: true)
      repo.update!(hidden_numbers: %w[mrr customers])
      get "/builder/shipnote"
      expect(figure).to be_nil
    end
  end

  it "lists MRR and paying customers in the dashboard's table, in money, each with its switch" do
    sign_in_as(user)

    get "/api/progress/builder", params: { range: "30d", dashboard: 1 }

    cells = JSON.parse(response.body).dig("table", "rows").first["cells"].to_h { |cell| [ cell["key"], cell ] }
    expect(cells["mrr"]).to include("value" => "$4,210", "pick" => true)
    expect(cells["customers"]).to include("value" => "230", "pick" => true)
  end

  it "keeps them off the dashboard on Free too, whose one project shows them on its own view" do
    user.update!(pro: false)
    sign_in_as(user)

    get "/api/progress/builder", params: { range: "30d", dashboard: 1 }

    expect(JSON.parse(response.body).dig("table", "columns").map { |column| column["key"] }).not_to include("mrr", "customers")
  end

  it "writes a project whose revenue ended before the window at nothing, in its last currency" do
    RevenueDay.delete_all
    product = RevenueProduct.find_by!(external_id: "prod_m")
    product.revenue_days.create!(day: today - 200, currency: "eur", mrr: 90_000, subscriptions: 9)

    expect(response_status_of_view).to eq(200)
    expect(number("mrr")["value"]).to eq("€0")
    expect(number("customers")["value"]).to eq("0")

    get "/builder/shipnote"
    expect(figure.text.squish).to eq("€0 MRR · 0 paying customers · Verified with Stripe")
  end

  it "shows a new read at once, past the page's cache" do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    expect(number("mrr")["value"]).to eq("$4,210")

    RevenueDay.where(day: today).update_all(mrr: 500_000)
    user.revenue_accounts.first.update!(read_at: 1.minute.from_now)

    expect(number("mrr")["value"]).to eq("$5,000")
  end
end
