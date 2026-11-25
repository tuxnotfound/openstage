require "rails_helper"
require "support/revenue_data"

# The page is its builder's alone, so its script draws all of it: these read
# what the server hands the script (the island's props).
RSpec.describe "Analytics", type: :request do
  let(:user) { create(:user, pro: true, username: "builder") }

  def page
    Nokogiri::HTML(response.body)
  end

  def props
    JSON.parse(page.at_css("script#analytics-props").text)
  end

  def view
    props["initial"]
  end

  # The numbers a view names anywhere: its tiles, toggles, columns, the
  # numbers drawn and the chart's lines and tooltip.
  def numbers_named(json)
    [ json["tiles"], json["numbers"], json["table"]["columns"], json["chart"]["tips"] ].flatten.pluck("key") +
      json["drawn"] + json["defaultShow"] + json["chart"]["paths"].pluck("number")
  end

  it "sends a visitor who is not signed in home" do
    get "/analytics"
    expect(response).to redirect_to(root_path)
  end

  it "sends an old link to Openstage's own lists to the Openstage views tab, its other params kept" do
    sign_in_as(user)

    get "/analytics", params: { panels: "openstage", range: "90d" }

    expect(response).to redirect_to("/analytics?range=90d&tab=openstage")
  end

  context "as a Pro builder" do
    let!(:repo) { create(:github_repo, user: user, name: "app", full_name: "builder/app", homepage: "https://app.example") }

    # Saturday: the 30-day view runs from Sep 25, the window before it from
    # Aug 26 to Sep 24, where the first commit is.
    before do
      travel_to Time.utc(2026, 10, 24, 12)
      create(:entry, user: user, repo_name: "builder/app", occurred_at: 40.days.ago)
      create(:entry, user: user, repo_name: "builder/app", occurred_at: 2.days.ago)
      sign_in_as(user)
    end

    it "hands the whole page to its script, the window, the tabs and Pro's mark, wide as the screen, with Analytics in the header" do
      get "/analytics"

      expect(response).to have_http_status(:ok)
      expect(page.at_css("[data-react='analytics']").children).to be_empty
      expect(props.slice("endpoint", "defaultRange", "pro")).to eq("endpoint" => "/api/analytics", "defaultRange" => "30d", "pro" => true)
      expect(view.values_at("locked", "tab", "range")).to eq([ false, "overview", "30d" ])
      expect(view["tabs"].pluck("label")).to eq([ "Overview", "Commits", "Site visits", "MRR", "Openstage views" ])
      expect(page.css("header, main, footer").map { |part| part["class"].split.first }).to eq(%w[os-wide os-wide os-wide])
      expect(page.at_css("header nav[aria-label='Main'] a[aria-current='page']").text).to eq("Analytics")

      get "/dashboard"
      expect(page.at_css("header")["class"]).to eq("os-wrap")
    end

    it "counts an open for /admin once per tab and day, and none from the API" do
      2.times { get "/analytics" }
      get "/analytics", params: { tab: "commits", range: "90d" }
      get "/api/analytics", params: { tab: "mrr" }
      travel 1.day
      get "/analytics"

      opens = Event.named("analytics_opened").where(user: user).order(:day, :detail)
      expect(opens.pluck(:detail, :day)).to eq([ [ "commits", Date.new(2026, 10, 24) ], [ "overview", Date.new(2026, 10, 24) ],
                                                 [ "overview", Date.new(2026, 10, 25) ] ])
    end

    it "opens each tab on its own numbers, its tiles, columns and rows in the tab's order, and Overview for a tab it does not know" do
      repo.update!(site_source: "script", site_set_up_at: 30.days.ago)
      repo.site_visit_days.create!(day: Date.new(2026, 10, 22), visits: 30, visitors: 9)
      create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "a")
      user.project_clicks.create!(repo_name: "builder/app", kind: "visit", clicked_at: 1.day.ago)
      tab = ->(key) { get("/analytics", params: { tab: key }) && view }

      overview = tab.call(nil)
      expect(overview["tiles"].map { |tile| tile.values_at("key", "figure") }).to eq([ [ "commits", false ], [ "visits", false ], [ "views", false ], [ "clicks", false ] ])
      expect(overview["table"]["columns"].pluck("key")).to eq(%w[commits visits site_visitors views visitors clicks])
      expect([ overview["drawn"], overview["rowsLabel"], overview["table"]["rows"].pluck("key") ]).to eq([ %w[commits visits], "Pages", %w[page builder/app] ])

      visits = tab.call("visits")
      expect([ visits["tiles"].map { |tile| tile.values_at("key", "figure") }, visits["drawn"], visits["rowsLabel"] ])
        .to eq([ [ [ "visits", false ], [ "site_visitors", true ] ], %w[visits], "Projects" ])
      expect(tab.call("commits")["table"]["columns"].pluck("key")).to eq(%w[commits])
      expect(tab.call("openstage")["tiles"].pluck("key")).to eq(%w[views visitors clicks])
      expect(tab.call("nope")["tab"]).to eq("overview")
      expect(props["endpoint"]).to eq("/api/analytics")
      get "/analytics", params: { tab: "visits" }
      expect(props["endpoint"]).to eq("/api/analytics?tab=visits")
    end

    it "holds a tab's own lists and no other tab's" do
      repo.update!(site_source: "script", site_set_up_at: 30.days.ago)
      repo.site_visit_counts.create!(kind: "country", value: "PT", count: 4, day: Date.new(2026, 10, 22))
      create(:profile_view, user: user, viewed_at: 2.days.ago, referrer: "news.ycombinator.com", country: "ES")

      get "/analytics"
      expect(view.values_at("site", "pages")).to eq([ nil, nil ])

      get "/analytics", params: { tab: "visits" }
      expect([ view["site"]["countries"]["rows"].pluck("label"), view["pages"] ]).to eq([ [ "Portugal" ], nil ])

      get "/analytics", params: { tab: "openstage" }
      expect([ view["pages"]["sources"]["rows"].pluck("label"), view["pages"]["countries"]["rows"].pluck("label"), view["site"] ]).to eq([ [ "Hacker News" ], [ "Spain" ], nil ])
    end

    it "draws the numbers and the pages asked for, and still reads analytics' old links" do
      create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "a")

      get "/analytics", params: { show: "views,commits", projects: "builder/app" }
      expect([ view["drawn"], view["selected"], view["chart"]["ariaLabel"] ]).to eq([ %w[views commits], [ "builder/app" ], "Commits per day by page, last 30 days" ])
      expect(view["chart"]["note"]).to eq("None of the pages in view counts views.")

      get "/analytics", params: { metric: "views", pages: [ "page" ] }
      expect([ view["drawn"], view["selected"] ]).to eq([ %w[views], [ "page" ] ])
    end

    it "keeps on the chart and the table the numbers a project's builder hides from visitors, and changes nothing visitors see" do
      repo.site_visit_days.create!(day: Date.new(2026, 10, 22), visits: 30, visitors: 9)
      repo.update!(hidden_numbers: %w[commits visits site_visitors])

      get "/analytics", params: { show: "visits" }
      cells = view["table"]["rows"].find { |row| row["key"] == "builder/app" }["cells"]
      expect(cells.map { |cell| [ cell["key"], cell["value"] ] }).to eq([ [ "commits", "1" ], [ "visits", "30" ], [ "site_visitors", "9" ] ])

      get "/api/progress/builder", params: { project: "builder/app", range: "30d" }
      expect(response.parsed_body["numbers"].pluck("key")).not_to include("visits")
    end

    it "marks what shipped and was published on the chart, on every tab" do
      create(:entry, user: user, repo_name: "builder/app", entry_type: "milestone", source: "manual", title: "Launched", occurred_at: 3.days.ago)

      get "/analytics"
      expect(view["chart"]["marks"].map { |mark| [ mark["key"], mark["entries"].pluck("title") ] }).to eq([ [ "builder/app", [ "Launched" ] ] ])
      get "/analytics", params: { tab: "commits" }
      expect(view["chart"]["marks"].size).to eq(1)
    end

    it "says under an empty chart what fills it, as far as the tab asks" do
      get "/analytics", params: { tab: "visits" }
      expect(props["step"]).to eq("text" => "Connect your site to count its visits.", "label" => "Set up site visits", "href" => "/dashboard/site-visits")

      get "/analytics", params: { tab: "mrr" }
      expect(props["step"]).to eq("text" => "Connect Stripe to show your MRR.", "label" => "Connect Stripe", "href" => "/settings?tab=integrations")

      get "/analytics", params: { tab: "commits" }
      expect(props["step"]).to be_nil
    end

    context "with revenue" do
      before do
        account = user.revenue_accounts.create!(provider: "stripe", api_key: "rk_test_ok", read_at: Time.current, read_through: Time.current.in_time_zone(user.zone).to_date)
        product = account.revenue_products.create!(external_id: "prod_m", name: "Monthly", github_repo: repo)
        revenue_day(product, day: Date.new(2026, 9, 20), currency: "usd", mrr: 200_000, subscriptions: 100)
        revenue_day(product, day: Date.new(2026, 10, 24), currency: "usd", mrr: 421_000, subscriptions: 230)
      end

      def tile(key, tab: nil)
        get "/api/analytics", params: { range: "30d", tab: tab }.compact
        response.parsed_body["tiles"].find { |each| each["key"] == key }
      end

      it "shows MRR and paying customers where they stand now, on Overview and MRR, hidden or not" do
        repo.update!(hidden_numbers: %w[mrr customers])

        expect(tile("mrr")).to include("value" => "$4,210", "figure" => false)
        expect(tile("customers", tab: "mrr")).to include("value" => "230", "figure" => false)
        get "/analytics", params: { tab: "mrr" }
        expect([ view["drawn"], view["table"]["rows"].pluck("key") ]).to eq([ %w[mrr], %w[builder/app] ])
      end

      it "takes both off while Stripe refuses the key" do
        user.revenue_accounts.first.update!(refused_at: Time.current)

        expect(tile("mrr")).to be_nil
        expect(tile("customers")).to be_nil
      end
    end
  end

  context "as a Free builder" do
    let(:user) { create(:user, pro: false, username: "builder") }
    let!(:held) { create(:github_repo, user: user, name: "app", full_name: "builder/app", site_source: "script", site_set_up_at: 20.days.ago) }
    let!(:paused) { create(:github_repo, user: user, name: "lib", full_name: "builder/lib", site_source: "script", site_set_up_at: 10.days.ago) }

    # Both projects counted site visits; the second while its builder was on Pro.
    before do
      travel_to Time.utc(2026, 10, 24, 12)
      create(:entry, user: user, repo_name: "builder/app", occurred_at: 2.days.ago)
      create(:entry, user: user, repo_name: "builder/lib", occurred_at: 3.days.ago)
      held.site_visit_days.create!(day: Date.new(2026, 10, 22), visits: 30, visitors: 9)
      paused.site_visit_days.create!(day: Date.new(2026, 10, 22), visits: 7, visitors: 3)
      paused.site_visit_counts.create!(kind: "page", value: "/lib", count: 7, day: Date.new(2026, 10, 22))
      create(:profile_view, user: user, viewed_at: 2.days.ago, referrer: "news.ycombinator.com")
      user.project_clicks.create!(repo_name: "builder/app", kind: "visit", clicked_at: 1.day.ago)
      product = user.revenue_accounts.create!(provider: "stripe", api_key: "rk_test_ok", read_at: Time.current, read_through: Date.new(2026, 10, 24))
                    .revenue_products.create!(external_id: "prod_m", name: "Monthly", github_repo: held)
      revenue_day(product, day: Date.new(2026, 10, 20), mrr: 1_000, subscriptions: 1)
      sign_in_as(user)
    end

    it "opens Overview, Commits and Site visits, naming none of Pro's numbers, with no stage, and Analytics in the header" do
      [ nil, "commits", "visits" ].each do |tab|
        get "/analytics", params: { tab: tab }.compact

        expect(response).to have_http_status(:ok)
        expect(numbers_named(view).uniq - %w[commits active_days visits site_visitors]).to eq([])
        expect(view["table"]["rows"].pluck("key")).not_to include("page")
        expect(response.body).not_to include("Paying customers", "New followers", "Clicks out")
      end
      expect(props["pro"]).to be(false)
      expect(page.at_css("header nav[aria-label='Main']").text).to include("Analytics")
    end

    it "shows the site visits of its one project alone, the other's Paused, and lists that one's pages alone" do
      get "/analytics"
      cells = view["table"]["rows"].to_h { |row| [ row["key"], row["cells"].find { |cell| cell["key"] == "visits" }.values_at("value", "link") ] }
      expect(cells.transform_values { |value, link| [ value, link&.fetch("text") ] }).to eq("builder/app" => [ "30", nil ], "builder/lib" => [ nil, "Paused" ])
      expect(view["tiles"].find { |tile| tile["key"] == "visits" }["value"]).to eq("30")

      get "/analytics", params: { tab: "visits" }
      expect(view["site"]["pages"]).to eq("rows" => [], "empty" => "No page views in the last 30 days.")
    end

    it "answers MRR and Openstage views with the Go Pro view alone, the API with 403" do
      %w[mrr openstage].each do |tab|
        get "/analytics", params: { tab: tab, range: "90d" }

        expect(response).to have_http_status(:ok)
        expect(view.keys).to contain_exactly("locked", "tab", "tabs", "pitch", "checkout")
        expect(view["tabs"].select { |each| each["pro"] }.pluck("key")).to eq(%w[mrr openstage])
        expect(props["step"]).to be_nil

        get "/api/analytics", params: { tab: tab }
        expect(response).to have_http_status(:forbidden)
      end
      get "/analytics", params: { panels: "openstage" }
      follow_redirect!
      expect(view["locked"]).to be(true)
      expect(Event.named("analytics_opened").where(user: user).pluck(:detail)).to contain_exactly("mrr", "openstage")
    end
  end
end
