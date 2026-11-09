require "rails_helper"

RSpec.describe "A chart with nothing to draw", type: :request do
  let(:user) { create(:user, username: "builder") }
  let!(:repo) { create(:github_repo, user: user, name: "shipnote", full_name: "builder/shipnote") }

  before { create(:entry, user: user, repo_name: repo.full_name, occurred_at: 200.days.ago) }

  def step
    Nokogiri::HTML(response.body).at_css("[data-chart-step]")
  end

  def island
    JSON.parse(Nokogiri::HTML(response.body).at_css("#progress-props").text)
  end

  it "shows a visitor no empty plot, no note and nothing to connect" do
    get "/builder", params: { range: "30d" }

    expect(Nokogiri::HTML(response.body).css(".os-chart")).to be_empty
    expect(step).to be_nil
    expect(island["step"]).to be_nil
  end

  it "shows its builder, on their own page, the one thing to connect, with no empty plot" do
    sign_in_as(user)

    get "/builder", params: { range: "30d" }

    expect(Nokogiri::HTML(response.body).css(".os-chart")).to be_empty
    expect(step.text.squish).to eq("Connect your site to count its visits. Set up site visits")
    expect(step.at_css("a")["href"]).to eq("/settings?tab=integrations")
    expect(island["step"]).to include("label" => "Set up site visits")
  end

  it "sends the step along even over a chart with lines, for when the window changes, and shows it only without them" do
    create(:entry, user: user, repo_name: repo.full_name, occurred_at: 1.day.ago)
    sign_in_as(user)

    get "/builder", params: { range: "30d" }

    expect(step).to be_nil
    expect(island["step"]).to include("label" => "Set up site visits")
  end

  it "sends a project's page to that project's own view, which opens" do
    sign_in_as(user)

    get "/builder/shipnote", params: { range: "30d" }

    expect(step.text.squish).to eq("Connect your site to count its visits. Set up site visits")
    get step.at_css("a")["href"]
    expect(response).to have_http_status(:ok)
  end

  it "leaves a builder's page alone with nothing to connect" do
    repo.update!(site_set_up_at: 1.day.ago)
    user.revenue_accounts.create!(provider: "stripe", api_key: "rk_test_ok")
    sign_in_as(user)

    get "/builder", params: { range: "30d" }

    expect(step).to be_nil
  end

  it "keeps the plot and the note on the dashboard, and adds the step" do
    sign_in_as(user)

    get "/dashboard", params: { range: "30d" }

    page = Nokogiri::HTML(response.body)
    expect(page.css(".os-chart").size).to eq(1)
    expect(page.text).to include("No commits in the last 30 days.")
    expect(step.text.squish).to eq("Connect your site to count its visits. Set up site visits")
  end

  it "asks a builder with no repos at all to connect GitHub" do
    Entry.delete_all
    sign_in_as(user)

    get "/dashboard"

    expect(step.text.squish).to eq("Connect your repos to see your commits here. Connect GitHub")
    expect(step.at_css("a")["href"]).to eq("/github_app/install")
  end
end
