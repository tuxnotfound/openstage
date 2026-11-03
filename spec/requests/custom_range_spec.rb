require "rails_helper"

# The window's fifth pill: days the builder picks, in the range param as
# "2026-09-01..2026-09-30", or from the form without the script as from and
# to, on every chart page.
RSpec.describe "Days picked for a chart's window", type: :request do
  let(:user) { create(:user, username: "builder", pro: true) }
  let!(:repo) { create(:github_repo, user: user, name: "app", full_name: "builder/app") }
  let(:range) { "2026-09-01..2026-09-30" }

  # Thursday Oct 15: app's first commit in June, one in August, three in
  # September and one on Oct 10; lib's one in September.
  before do
    travel_to Time.utc(2026, 10, 15, 12)
    [ [ 6, 2 ], [ 8, 20 ], [ 9, 3 ], [ 9, 10 ], [ 9, 29 ], [ 10, 10 ] ].each do |month, day|
      create(:entry, user: user, repo_name: "builder/app", occurred_at: Time.utc(2026, month, day, 12))
    end
    create(:entry, user: user, repo_name: "builder/lib", occurred_at: Time.utc(2026, 9, 4, 12))
    create(:entry, user: user, entry_type: "milestone", source: "manual", title: "Shipped in September", occurred_at: Time.utc(2026, 9, 20, 12))
  end

  def page
    Nokogiri::HTML(response.body)
  end

  def window
    page.at_css("[aria-label='Time range']")
  end

  def custom
    window.at_css("details")
  end

  def chart_label
    page.at_css("svg[role='img']")["aria-label"]
  end

  def query(href)
    Rack::Utils.parse_query(URI(href).query)
  end

  # The chart's links to its own page but the window's pills, which each
  # name their own window.
  def chart_links(path)
    page.css("[data-react] a").map { |a| a["href"] }.select { |href| URI(href).path == path } - window.css("a").map { |a| a["href"] }
  end

  # The form's hidden fields and date fields, by name.
  def form_fields
    custom.css("form input").to_h { |input| [ input["name"], input.to_h.slice("type", "value", "min", "max") ] }
  end

  # label: the chart's, for the days picked; commits: the toggle's count.
  shared_examples "a window of days picked" do |path, label, commits|
    it "draws them, names them on the Pick dates pill and keeps them on every link" do
      get path, params: { range: range }

      expect(chart_label).to eq(label)
      expect(page.at_css("[aria-label='Numbers on the chart']").text.squish).to match(/\A(On GitHub )?Commits #{commits}\b/)
      expect(page.css(".os-xlabs span").map(&:text)).to eq([ "Sep 1", "Sep 16", "Sep 30" ])
      expect(window.css("a[aria-current]")).to be_empty
      expect(custom.at_css("summary").text.squish).to eq("1 Sep – 30 Sep")
      expect(custom.at_css("summary")["class"]).to include("on")
      expect(query(window.css("a").find { |a| a.text == "90 days" }["href"])).to include("range" => "90d")
      expect(chart_links(path).map { |href| query(href)["range"] }.uniq).to eq(path == "/builder/app" ? [] : [ range ])
    end

    it "offers a form of two dates without the script, from the first activity to today" do
      get path, params: { range: range }

      expect(custom.at_css("form")["method"]).to eq("get")
      expect(form_fields["from"]).to eq("type" => "date", "value" => "2026-09-01", "min" => "2026-06-02", "max" => "2026-10-15")
      expect(form_fields["to"]).to eq("type" => "date", "value" => "2026-09-30", "min" => "2026-06-02", "max" => "2026-10-15")
      expect(form_fields.keys).not_to include("range")
      expect(custom.at_css("button[type='submit']").text).to eq("Show")
    end

    it "reads the form's from and to, reversed, as the same days, and drops them from its links" do
      get path, params: { from: "2026-09-30", to: "2026-09-01", range: "90d" }

      expect(chart_label).to eq(label)
      hrefs = window.css("a").map { |a| a["href"] } + chart_links(path)
      expect(hrefs.flat_map { |href| query(href).keys }).not_to include("from", "to")
      expect(chart_links(path).map { |href| query(href)["range"] }.uniq).to eq(path == "/builder/app" ? [] : [ range ])
    end

    it "falls back to the page's default for days that are not days" do
      get path, params: { range: "2026-09-31..2026-10-02" }

      expect(chart_label).to end_with("last 30 days")
      expect(custom.at_css("summary .sr-only").text).to eq("Pick dates")
    end
  end

  describe "the stage" do
    it_behaves_like "a window of days picked", "/builder", "7-day average of commits per day by project, 1 Sep – 30 Sep", 4

    it "lists what shipped between them, and keeps its one canonical address" do
      get "/builder", params: { range: range }

      expect(page.at_css("section[aria-labelledby='whats-new']").text.squish).to include("1 between 1 Sep and 30 Sep", "Shipped in September")
      expect(page.at_css("link[rel='canonical']")["href"]).to eq("http://www.example.com/builder")
    end

    it "keeps the projects in view on the form" do
      create(:entry, user: user, repo_name: "builder/lib", occurred_at: Time.utc(2026, 9, 4, 12))
      get "/builder", params: { range: range, projects: "builder/app", show: "commits" }

      expect(form_fields["projects"]).to include("type" => "hidden", "value" => "builder/app")
    end
  end

  describe "a project's page" do
    it_behaves_like "a window of days picked", "/builder/app", "7-day average of commits per day by project, 1 Sep – 30 Sep", 3

    it "keeps its one canonical address" do
      get "/builder/app", params: { range: range }

      expect(page.at_css("link[rel='canonical']")["href"]).to eq("http://www.example.com/builder/app")
    end
  end

  describe "the dashboard" do
    before { sign_in_as(user) }

    it_behaves_like "a window of days picked", "/dashboard", "7-day average of commits per day by project, 1 Sep – 30 Sep", 4

    it "keeps the entry filters on the form and its links, and compares with as many days before" do
      get "/dashboard", params: { from: "2026-09-01", to: "2026-09-30", q: "work" }

      expect(form_fields["q"]).to include("type" => "hidden", "value" => "work")
      expect(query(window.css("a").first["href"])).to eq("q" => "work")
      expect(page.at_css("[aria-label='Numbers on the chart']").text.squish).to include("Commits 4 ▲up 300%")
    end
  end

  describe "analytics" do
    before { sign_in_as(user) }

    it_behaves_like "a window of days picked", "/analytics", "Commits per day by page, 1 Sep – 30 Sep", 4

    it "says what its changes compare with, and counts no visit after the last day picked" do
      create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 10, 12), referrer: "news.ycombinator.com")
      get "/analytics", params: { range: range, panels: "openstage" }

      expect(response.body).to include("Changes compare each value with the 30 days before.", "No views between 1 Sep and 30 Sep.")
    end
  end

  describe "the chart's API" do
    it "answers with the days, the calendar's bounds and their name, for each page" do
      get "/api/progress/builder", params: { range: "2026-09-30..2026-09-01" }
      json = response.parsed_body

      expect(json).to include("range" => range, "words" => "1 Sep – 30 Sep")
      expect(json["calendar"]).to eq("today" => "2026-10-15", "earliest" => "2026-06-02",
                                     "picked" => { "from" => "2026-09-01", "to" => "2026-09-30", "name" => "1 Sep – 30 Sep" })

      get "/api/progress/builder", params: { range: "30d" }
      expect(response.parsed_body["calendar"]).to include("picked" => nil)

      sign_in_as(user)
      get "/api/analytics", params: { range: "2026-10-01..2099-01-01" }
      expect(response.parsed_body).to include("range" => "2026-10-01..2026-10-15", "words" => "1 Oct – 15 Oct")
    end
  end
end
