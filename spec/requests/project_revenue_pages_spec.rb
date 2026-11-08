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

  it "shows a new read at once, past the page's cache" do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    expect(number("mrr")["value"]).to eq("$4,210")

    RevenueDay.where(day: today).update_all(mrr: 500_000)
    user.revenue_accounts.first.update!(read_at: 1.minute.from_now)

    expect(number("mrr")["value"]).to eq("$5,000")
  end
end
