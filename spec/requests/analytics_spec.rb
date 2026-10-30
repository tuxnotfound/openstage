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
    page.css("[aria-label='Numbers on the chart'] [aria-current='true'], [aria-label='More numbers'] [aria-current='true']").uniq
        .map { |toggle| toggle.text.squish.split.first }
  end

  # Each cell's words, its label for phones first.
  def cells(key)
    page.at_css("[data-chart-row='#{key}']").css("td").map { |cell| cell.text.squish }
  end

  def query(link)
    Rack::Utils.parse_query(URI(link["href"]).query)
  end

  # A panel's words, a space between each element's.
  def panel(id)
    page.at_css("section[aria-labelledby='#{id}']").xpath(".//text()").map(&:text).join(" ").squish
  end

  def count(repo, kind, value, count, day: Date.new(2026, 10, 20))
    repo.site_visit_counts.create!(kind: kind, value: value, count: count, day: day)
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

    it "says so when nothing happened on Openstage" do
      get "/analytics", params: { panels: "openstage" }

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
      expect(toggles.text.squish).to eq("On GitHub Commits 1 ± 0% On your websites + Site visits 30 ▲up 200% + Site visitors 9 ± 0% + 2 more On Openstage + Visitors 1 + Views 1")
      expect(toggles.css("[aria-current='true']").map { |drawn| [ drawn.name, drawn.text.squish ] }).to eq([ [ "span", "Commits 1 ± 0%" ] ])
      expect(page.at_css("svg[role='img']")["aria-label"]).to eq("Commits per day by page, last 30 days")
      expect(page.at_css("[aria-label='Time range'] a[aria-current='page']").text).to eq("30 days")
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
        .to eq([ "Pages", "Commits", "Site visits", "Site visitors", "Visitors", "Views", "New followers", "Clicks out" ])
      expect(cells("page")).to eq([ "Commits –", "Site visits –", "Site visitors –", "Visitors 2", "Views 2", "New followers –", "Clicks out –" ])
      expect(cells("builder/app")).to eq([ "Commits 0 ▼down 100%", "Site visits 30", "Site visitors 9", "Visitors 1", "Views 1", "New followers 1", "Clicks out 1" ])
      expect(response.body).to include("Hacker News", "Twitter / X", "PT", "Visit app.example")
    end

    it "draws the numbers and the pages asked for, and still reads analytics' old links" do
      repo.site_visit_days.create!(day: Date.new(2026, 10, 22), visits: 30, visitors: 9)
      create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "a")

      get "/analytics", params: { show: "views,commits", projects: "builder/app" }
      expect(drawn).to eq(%w[Commits Views])
      expect(page.at_css("[data-chart-row='page'] th > span > a:first-child")["aria-current"]).to be_nil
      expect(page.at_css("svg[role='img']")["aria-label"]).to eq("Views and commits per day by page, last 30 days")
      expect(response.body).to include("No commits in the last 30 days. None of the pages in view counts views.")

      get "/analytics", params: { metric: "site", pages: [ "builder/app" ] }
      expect(drawn).to eq(%w[Site])
      expect(page.at_css("[data-chart-row='builder/app'] [role='link'][aria-disabled='true']")).to be_present
    end

    it "links each control to its view, leaving the page's defaults out" do
      create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "a")

      get "/analytics"

      expect(query(toggles.css("a").find { |link| link.text.include?("Views") })).to eq("show" => "commits,views")
      expect(query(page.css("[aria-label='Time range'] a").find { |link| link.text == "90 days" })).to eq("range" => "90d")
      expect(query(page.at_css("[data-chart-row='page'] th > span > a:first-child"))).to eq("projects" => "builder/app")
      expect(query(page.at_css("[data-chart-row='page'] a[aria-label='Show only Your stage']"))).to eq("projects" => "page")
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
      expect(toggles.text.squish).to eq("On GitHub Commits 0 ▼down 100% On your websites + Site visitors 9")
      expect(cells("builder/app")).to eq([ "Commits 0 ▼down 100%", "Site visitors 9" ])

      repo.update!(hidden_numbers: %w[visits site_visitors])
      get "/analytics", params: { show: "visits" }
      expect(toggles.text.squish).to eq("On GitHub Commits 0 ▼down 100%")
      expect(cells("builder/app")).to eq([ "Commits 0 ▼down 100%" ])
    end

    it "draws site visitors on their own over the days picked, saying a site visitor is one browser on one day" do
      repo.site_visit_days.create!(day: Date.new(2026, 10, 2), visits: 30, visitors: 9)
      repo.site_visit_days.create!(day: Date.new(2026, 10, 12), visits: 12, visitors: 4)

      get "/analytics", params: { show: "site_visitors", range: "2026-10-01..2026-10-10" }

      expect(drawn).to eq([ "Site" ])
      expect(toggles.at_css("[aria-current='true']").text.squish).to eq("Site visitors 9")
      expect(page.at_css("svg[role='img']")["aria-label"]).to start_with("Site visitors per day by page")
      expect(cells("builder/app")).to include("Site visitors 9")
      expect(response.body).to include("On a project's own website, counted by Openstage's script: site visits are page views; a site visitor is one browser on one day.")

      get "/api/analytics", params: { show: "site_visitors", range: "2026-10-01..2026-10-10" }
      expect(response.parsed_body["numbers"].find { |number| number["key"] == "site_visitors" }).to include("label" => "Site visitors", "value" => "9")
      expect(response.parsed_body["drawn"]).to eq([ "site_visitors" ])
    end

    it "shows where the badge and the embed were shown" do
      user.badge_impressions.create!(kind: "badge", viewed_at: 1.day.ago, referrer: "github.com", ip_hash: "x")
      user.badge_impressions.create!(kind: "badge", viewed_at: 1.day.ago, referrer: "example.com", ip_hash: "y")

      get "/analytics", params: { panels: "openstage" }

      expect(panel("badge-embed")).to include("README badge 2 · 2 sites", "Embed widget 0 · 0 sites")
    end

    describe "the panels under the chart" do
      def switch
        page.at_css("[role='group'][aria-label='Panels']")
      end

      before { repo.update!(site_source: "script", site_token: "os_a", site_set_up_at: 50.days.ago, site_first_visit_at: 50.days.ago) }

      it "opens on the builder's websites, each panel saying what it counts and where, the sources named and the cap's Other rows last" do
        count(repo, "source", "news.ycombinator.com", 5)
        count(repo, "source", "t.co", 2)
        count(repo, "source", "x.com", 2)
        count(repo, "source", "openstage.dev", 3)
        count(repo, "source", SiteVisitCount::DIRECT, 4)
        count(repo, "source", "indiehackers.com", 1)
        count(repo, "source", SiteVisitCount::OTHER, 2)
        count(repo, "ref", "hn", 3)
        count(repo, "country", "PT", 6)
        count(repo, "page", "/pricing", 9)
        count(repo, "page", "/docs/*", 4)
        count(repo, "page", SiteVisitCount::OTHER, 7)
        create(:profile_view, user: user, viewed_at: 2.days.ago, referrer: "reddit.com")

        get "/analytics"

        expect(switch.css("a").map { |option| [ option.text, option["aria-current"] ] }).to eq([ [ "On your websites", "page" ], [ "On Openstage", nil ] ])
        expect(switch.parent.text.squish).to end_with("Visitors and page views on your websites, counted by Openstage's script.")
        expect(panel("site-sources")).to eq("Where visitors came from Visitors to your websites, by the site they came from, last 30 days. " \
                                            "Hacker News 5 Direct 4 Twitter / X 4 Openstage 3 indiehackers.com 1 Other 2 Countries PT 6")
        expect(panel("site-refs")).to eq("Ref tags Visitors by the ref or utm_source tag in their link, last 30 days. hn 3")
        expect(panel("site-pages")).to eq("Top pages Page views on your websites, by path, last 30 days. /pricing 9 /docs/* 4 Other 7")
        expect(page.css("section[aria-labelledby='site-sources'] [style]").map { |bar| bar["style"] }.first(2)).to eq([ "width: 100%", "width: 80%" ])
        expect(page.at_css("section[aria-labelledby='visitors-from']")).to be_nil
      end

      it "shows Openstage's own panels as before when the URL names them, and the websites' for a name it does not know" do
        count(repo, "source", "news.ycombinator.com", 5)
        create(:profile_view, user: user, viewed_at: 2.days.ago, referrer: "reddit.com", country: "ES")
        user.project_clicks.create!(repo_name: "builder/app", kind: "github", clicked_at: 1.day.ago)

        get "/analytics", params: { panels: "openstage" }

        expect(switch.css("a").map { |option| [ option.text, option["aria-current"] ] }).to eq([ [ "On your websites", nil ], [ "On Openstage", "page" ] ])
        expect(switch.parent.text.squish).to end_with("Views and clicks out on your stage and your project pages, and where your badge and embed were shown.")
        expect(panel("visitors-from")).to eq("Where visitors came from Views of your Openstage pages, by the site they came from, last 30 days. Reddit 1 Countries ES 1")
        expect(panel("links-followed")).to eq("Links they followed Clicks from your Openstage pages, last 30 days. View on GitHub app 1")
        expect(page.at_css("section[aria-labelledby='site-sources']")).to be_nil

        get "/analytics", params: { panels: "github" }
        expect(panel("site-sources")).to include("Hacker News 5")
      end

      it "links each option to its view without the script, and keeps the panels on every other link and the days form" do
        create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "a")

        get "/analytics", params: { range: "90d", show: "commits,views", projects: "builder/app" }
        expect(switch.css("a").map { |option| query(option) }).to eq([ { "range" => "90d", "show" => "commits,views", "projects" => "builder/app" },
                                                                       { "range" => "90d", "show" => "commits,views", "projects" => "builder/app", "panels" => "openstage" } ])

        get "/analytics", params: { panels: "openstage" }
        expect(query(page.css("[aria-label='Time range'] a").find { |link| link.text == "90 days" })).to eq("range" => "90d", "panels" => "openstage")
        expect(query(toggles.css("a").find { |link| link.text.include?("Views") })).to eq("show" => "commits,views", "panels" => "openstage")
        expect(query(page.at_css("[data-chart-row='page'] a[aria-label='Show only Your stage']"))).to eq("projects" => "page", "panels" => "openstage")
        expect(page.css("[aria-label='Time range'] form input[type='hidden']").map { |field| [ field["name"], field["value"] ] }).to eq([ [ "panels", "openstage" ] ])
      end

      it "follows the window, the days picked and the projects in view; with all in view, every project with website data, and never the stage" do
        quiet = create(:github_repo, user: user, name: "quiet", full_name: "builder/quiet", homepage: "https://quiet.example")
        lib = create(:github_repo, user: user, name: "lib", full_name: "builder/lib")
        create(:entry, user: user, repo_name: "builder/lib", occurred_at: 3.days.ago)
        count(repo, "page", "/", 3)
        count(repo, "page", "/old", 8, day: Date.new(2026, 9, 1))
        count(repo, "page", "/early", 2, day: Date.new(2026, 10, 2))
        count(quiet, "page", "/quiet", 5)
        count(lib, "page", "/lib", 1)

        get "/analytics"
        expect(page.css("[data-chart-row]").map { |row| row["data-chart-row"] }).to eq([ "page", "builder/app", "builder/lib" ])
        expect(panel("site-pages")).to end_with("/quiet 5 / 3 /early 2 /lib 1")

        get "/analytics", params: { range: "90d" }
        expect(panel("site-pages")).to end_with("/old 8 /quiet 5 / 3 /early 2 /lib 1")

        get "/analytics", params: { range: "2026-10-01..2026-10-10" }
        expect(panel("site-pages")).to eq("Top pages Page views on your websites, by path, 1 Oct – 10 Oct. /early 2")
        get "/analytics", params: { from: "2026-10-01", to: "2026-10-10" }
        expect(panel("site-pages")).to end_with("/early 2")

        get "/analytics", params: { projects: "builder/lib" }
        expect(panel("site-pages")).to end_with("by path, last 30 days. /lib 1")

        get "/analytics", params: { projects: "page" }
        expect(page.at_css("section[aria-labelledby='site-pages']")).to be_nil
        note = page.css("p.os-note").find { |each| each.text.include?("None of the projects") }
        expect([ note.text.squish, note.at_css("a") ]).to eq([ "None of the projects in view counts site visits.", nil ])
      end

      it "says when none of the projects in view counts site visits, with a link to set up the first one's, and when none came in the window" do
        repo.update!(site_source: nil)
        get "/analytics"
        note = page.css("p.os-note").find { |each| each.text.include?("None of the projects") }
        expect(note.text.squish).to eq("None of the projects in view counts site visits. Set up app's site visits")
        expect(note.at_css("a")["href"]).to eq("/projects/#{repo.id}/edit?site=open#site-visits")

        repo.update!(site_source: "script")
        count(repo, "page", "/", 3, day: Date.new(2026, 8, 1))
        get "/analytics"
        expect(page.css("p.os-note").map { |each| each.text.squish }).to include("No site visits in the last 30 days.")
        expect(response.body).not_to include("None of the projects in view counts site visits.")

        get "/analytics", params: { range: "all" }
        expect(panel("site-pages")).to end_with("/ 3")
      end
    end
  end
end
