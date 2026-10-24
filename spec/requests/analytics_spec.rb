require "rails_helper"

RSpec.describe "Analytics", type: :request do
  let(:user) { create(:user, pro: true, username: "builder") }
  let(:browser) { { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh) Safari/605.1.15" } }

  def page
    Nokogiri::HTML(response.body)
  end

  def row(key)
    page.at_css("[data-page-row='#{key}']").css("td").map { |cell| cell.text.squish }
  end

  it "sends a visitor who is not signed in home" do
    get "/analytics"
    expect(response).to redirect_to(root_path)
  end

  it "sends a free builder to the dashboard, saying it is Pro" do
    sign_in_as(create(:user, pro: false))
    get "/analytics"

    expect(response).to redirect_to(dashboard_path)
    expect(flash[:alert]).to match(/Pro/)
  end

  context "as a Pro builder" do
    let!(:repo) { create(:github_repo, user: user, name: "app", full_name: "builder/app", homepage: "https://app.example") }

    before do
      travel_to Time.utc(2026, 10, 24, 12)
      create(:entry, user: user, repo_name: "builder/app")
      sign_in_as(user)
    end

    it "says so when nothing happened" do
      get "/analytics"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No visits in the last 30 days.", "No visitors in the last 30 days.")
    end

    it "counts each page's visitors, views, new followers and clicks out, with where visitors came from" do
      create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "a", referrer: "news.ycombinator.com", country: "PT")
      create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "a", referrer: "news.ycombinator.com", country: "PT")
      user.project_views.create!(repo_name: "builder/app", viewed_at: 1.day.ago, ip_hash: "b", referrer: "x.com")
      user.subscriptions.create!(email: "fan@example.com", github_repo: repo, confirmed_at: 3.days.ago)
      user.project_clicks.create!(repo_name: "builder/app", kind: "visit", clicked_at: 1.day.ago)

      get "/analytics"

      expect(row("page")).to eq([ "1", "2", "–", "–", "–" ])
      expect(row("builder/app")).to eq([ "1", "1", "1", "1", "–" ])
      expect(page.at_css("nav[aria-label='Numbers']").text.squish).to include("Visitors 2", "Page views 3", "New followers 1", "Clicks out 1")
      expect(response.body).to include("Hacker News", "Twitter / X", "PT", "Visit app.example")
    end

    it "compares with the days just before" do
      create(:profile_view, user: user, viewed_at: 40.days.ago, ip_hash: "old")
      create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "new1")
      create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "new2")

      get "/analytics"

      expect(page.at_css(".os-big").text).to eq("2")
      expect(response.body).to include("100% vs the 30 days before")
    end

    it "narrows to the pages picked, and charts the number picked" do
      create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "a")
      user.project_views.create!(repo_name: "builder/app", viewed_at: 1.day.ago, ip_hash: "b")

      get "/analytics", params: { pages: [ "builder/app" ], metric: "views", range: "7d" }

      expect(page.css("[data-page-row]").map { |each| each["data-page-row"] }).to eq([ "builder/app" ])
      expect(page.at_css("p.os-label").text.squish).to eq("Page views · app, last 7 days")
      expect(page.at_css("svg[role='img']")["aria-label"]).to eq("Page views per day by page, last 7 days")
      switch = page.at_css("[aria-label='Pages'] [role='switch'][aria-label='Show Your page in the chart']")
      expect(switch["aria-checked"]).to eq("false")
      expect(Rack::Utils.parse_nested_query(URI(switch["href"]).query)["pages"]).to be_nil
      expect(page.at_css("[aria-label='Show app in the chart']")["aria-disabled"]).to eq("true")
    end

    it "draws 90 days a week a point, and falls back to 30 days for a range it does not know" do
      get "/analytics", params: { range: "90d" }
      expect(page.css("[data-chart-tooltip-template-param]").size).to eq(13)

      get "/analytics", params: { range: "1y" }
      expect(page.css("[data-chart-tooltip-template-param]").size).to eq(30)
    end

    it "shows where the badge and the embed were shown" do
      user.badge_impressions.create!(kind: "badge", viewed_at: 1.day.ago, referrer: "github.com", ip_hash: "x")
      user.badge_impressions.create!(kind: "badge", viewed_at: 1.day.ago, referrer: "example.com", ip_hash: "y")

      get "/analytics"

      expect(page.at_css("section[aria-labelledby='badge-embed']").text.squish).to include("README badge 2 · 2 sites", "Embed widget 0 · 0 sites")
    end
  end
end
