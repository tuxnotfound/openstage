require "rails_helper"

RSpec.describe "Analytics", type: :request do
  let(:user) { create(:user, pro: true, username: "builder") }

  def page
    Nokogiri::HTML(response.body)
  end

  def toggles
    page.at_css("[aria-label='Numbers on the chart']")
  end

  # The numbers drawn, wherever their toggles sit.
  def drawn
    page.css("section[aria-label='Numbers'] [aria-current='true']").map { |toggle| toggle.text.squish.split.first }
  end

  # Each cell's words, its label for phones first.
  def cells(key)
    page.at_css("[data-chart-row='#{key}']").css("td").map { |cell| cell.text.squish }
  end

  def query(link)
    Rack::Utils.parse_query(URI(link["href"]).query)
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

    # Saturday: the 30-day view runs from Sep 25, the window before it from
    # Aug 26 to Sep 24, where the first commit is.
    before do
      travel_to Time.utc(2026, 10, 24, 12)
      create(:entry, user: user, repo_name: "builder/app", occurred_at: 40.days.ago)
      sign_in_as(user)
    end

    it "says so when nothing happened" do
      get "/analytics"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No visits in the last 30 days.", "No clicks out in the last 30 days.")
    end

    it "opens on commits alone over the last 30 days, the window beside the title, the numbers in their groups with their changes" do
      repo.site_visit_days.create!(day: Date.new(2026, 10, 22), visits: 30, visitors: 9)
      repo.site_visit_days.create!(day: Date.new(2026, 9, 10), visits: 10, visitors: 9)
      create(:entry, user: user, repo_name: "builder/app", occurred_at: 2.days.ago)
      create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "a")

      get "/analytics"

      expect(toggles.css("[role='group']").map { |group| group["aria-label"] }).to eq([ "On GitHub", "On your websites", "More numbers", "On Openstage" ])
      expect(toggles.text.squish).to eq("On GitHub Commits 1 ± 0% On your websites + Site visits 30 ▲up 200% + 2 more On Openstage + Visitors 1 + Views 1")
      expect(toggles.css("[aria-current='true']").map { |drawn| [ drawn.name, drawn.text.squish ] }).to eq([ [ "span", "Commits 1 ± 0%" ] ])
      expect(page.at_css("svg[role='img']")["aria-label"]).to eq("Commits per day by page, last 30 days")
      expect(page.at_css("nav[aria-label='Time range'] a[aria-current='page']").text).to eq("30 days")
      expect(response.body).to include("Changes compare each value with the 30 days before.")
    end

    it "says each change's direction in words to a screen reader, the arrow only to the eye" do
      repo.site_visit_days.create!(day: Date.new(2026, 10, 22), visits: 30, visitors: 9)
      repo.site_visit_days.create!(day: Date.new(2026, 9, 10), visits: 10, visitors: 9)

      get "/analytics"

      change = toggles.css("[aria-label='On your websites'] a span").find { |span| span.at_css(".sr-only") }
      expect(change.at_css("[aria-hidden='true']").text).to eq("▲")
      expect(change.at_css(".sr-only").text).to eq("up")
    end

    it "folds Openstage's own numbers behind a button that opens them in place, and shows them in a row of their own while one is drawn" do
      repo.site_visit_days.create!(day: Date.new(2026, 10, 22), visits: 30, visitors: 9)
      create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "a")

      get "/analytics"
      expect(toggles.at_css("details summary").text).to eq("+ 2 more")
      expect(toggles.css("details [role='group']").map { |group| group["aria-label"] }).to eq([ "More numbers", "On Openstage" ])
      expect(page.at_css("[aria-label='Numbers on the chart'] + [aria-label='More numbers']")).to be_nil

      get "/analytics", params: { show: "commits,views" }
      expect(toggles.at_css("details")).to be_nil
      expect(page.at_css("[aria-label='Numbers on the chart'] + [aria-label='More numbers']").text.squish).to eq("On Openstage + Visitors 1 Views 1")
    end

    it "lists every page under the chart in their fixed order, each value with its change, the builder's page with no commits or site visits" do
      repo.site_visit_days.create!(day: Date.new(2026, 10, 22), visits: 30, visitors: 9)
      create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "a")
      create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "b", referrer: "news.ycombinator.com", country: "PT")
      user.project_views.create!(repo_name: "builder/app", viewed_at: 1.day.ago, ip_hash: "c", referrer: "x.com")
      user.subscriptions.create!(email: "fan@example.com", github_repo: repo, confirmed_at: 3.days.ago)
      user.project_clicks.create!(repo_name: "builder/app", kind: "visit", clicked_at: 1.day.ago)

      get "/analytics"

      expect(page.css("[data-chart-row]").map { |row| row["data-chart-row"] }).to eq([ "page", "builder/app" ])
      expect(page.css("[data-chart-table] thead th").map { |head| head.text.squish })
        .to eq([ "Pages", "Commits", "Site visits", "Visitors", "Views", "New followers", "Clicks out" ])
      expect(cells("page")).to eq([ "Commits –", "Site visits –", "Visitors 2", "Views 2", "New followers –", "Clicks out –" ])
      expect(cells("builder/app")).to eq([ "Commits 0 ▼down 100%", "Site visits 30", "Visitors 1", "Views 1", "New followers 1", "Clicks out 1" ])
      expect(response.body).to include("Hacker News", "Twitter / X", "PT", "Visit app.example")
    end

    it "draws the numbers and the pages asked for, and still reads analytics' old links" do
      repo.site_visit_days.create!(day: Date.new(2026, 10, 22), visits: 30, visitors: 9)
      create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "a")

      get "/analytics", params: { show: "views,commits", projects: "builder/app" }
      expect(drawn).to eq(%w[Commits Views])
      expect(page.at_css("[data-chart-row='page'] [role='checkbox']")["aria-checked"]).to eq("false")
      expect(page.at_css("svg[role='img']")["aria-label"]).to eq("Views and commits per day by page, last 30 days")
      expect(response.body).to include("No commits in the last 30 days. None of the pages in view counts views.")

      get "/analytics", params: { metric: "site", pages: [ "builder/app" ] }
      expect(drawn).to eq(%w[Site])
      expect(page.at_css("[data-chart-row='builder/app'] [aria-disabled='true']")).to be_present
    end

    it "links each control to its view, leaving the page's defaults out" do
      create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "a")

      get "/analytics"

      expect(query(toggles.css("a").find { |link| link.text.include?("Views") })).to eq("show" => "commits,views")
      expect(query(page.css("nav[aria-label='Time range'] a").find { |link| link.text == "90 days" })).to eq("range" => "90d")
      expect(query(page.at_css("[data-chart-row='page'] [role='checkbox']"))).to eq("projects" => "builder/app")
      expect(query(page.at_css("[data-chart-row='page'] a[aria-label='Show only Your page']"))).to eq("projects" => "page")
    end

    it "draws 90 days by week and 12 months by month, and the last 30 days for a window it does not know" do
      create(:entry, user: user, repo_name: "builder/app", occurred_at: 200.days.ago)

      get "/analytics", params: { range: "90d" }
      expect(page.at_css("svg[role='img']")["aria-label"]).to eq("Commits per week by page, last 90 days")

      get "/analytics", params: { range: "12m" }
      expect(page.at_css("svg[role='img']")["aria-label"]).to eq("Commits per month by page, last 12 months")

      get "/analytics", params: { range: "all" }
      expect(response.body).not_to include("Changes compare")

      get "/analytics", params: { range: "7d" }
      expect(page.at_css("svg[role='img']")["aria-label"]).to eq("Commits per day by page, last 30 days")
    end

    it "leaves out of the chart and the table the numbers a project's builder hides" do
      repo.site_visit_days.create!(day: Date.new(2026, 10, 22), visits: 30, visitors: 9)
      repo.update!(hidden_numbers: %w[visits])

      get "/analytics", params: { show: "visits" }

      expect(toggles.text.squish).to eq("On GitHub Commits 0 ▼down 100%")
      expect(cells("builder/app")).to eq([ "Commits 0 ▼down 100%" ])
    end

    it "shows where the badge and the embed were shown" do
      user.badge_impressions.create!(kind: "badge", viewed_at: 1.day.ago, referrer: "github.com", ip_hash: "x")
      user.badge_impressions.create!(kind: "badge", viewed_at: 1.day.ago, referrer: "example.com", ip_hash: "y")

      get "/analytics"

      expect(page.at_css("section[aria-labelledby='badge-embed']").text.squish).to include("README badge 2 · 2 sites", "Embed widget 0 · 0 sites")
    end
  end
end
