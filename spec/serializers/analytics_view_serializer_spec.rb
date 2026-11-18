require "rails_helper"

RSpec.describe AnalyticsViewSerializer do
  let(:user) { create(:user, pro: true) }

  before do
    travel_to Time.utc(2026, 10, 24, 12)
    create(:entry, user: user, repo_name: "me/app", occurred_at: 2.days.ago)
    create(:entry, user: user, repo_name: "me/app", occurred_at: 40.days.ago)
  end

  # Overview unless a tab is named.
  def view(tab: nil, **options)
    described_class.new(Analytics::ReportService.new(user: user, tab: Analytics::Tab.find(tab), **options).tap(&:call!)).as_json
  end

  it "sends the chart filter with a change on every tile and every cell, the tab, its links, and what the changes compare with" do
    json = view

    expect(json["tiles"].sole).to include("key" => "commits", "figure" => false, "suffix" => nil, "change" => { "arrow" => "±", "text" => "0%", "up" => nil })
    expect(json["table"]["rows"].map { |row| [ row["name"], row["cells"].first.slice("value", "change") ] })
      .to eq([ [ "Your stage", { "value" => nil, "change" => nil } ], [ "app", { "value" => "1", "change" => { "arrow" => "±", "text" => "0%", "up" => nil } } ] ])
    expect(json["table"]["rows"].pluck("colorClass", "drawable")).to eq([ [ "os-project-none", false ], [ "os-project-1", true ] ])
    expect(json).to include("locked" => false, "tab" => "overview", "rowsLabel" => "Pages", "site" => nil, "pages" => nil, "commits" => nil, "revenue" => nil,
                            "changesNote" => "Changes compare each value with the 30 days before.", "quiet" => "in the last 30 days")
    expect(json["tabs"].map { |tab| tab.values_at("key", "label", "pro", "path") })
      .to eq([ [ "overview", "Overview", false, "/analytics" ], [ "commits", "Commits", false, "/analytics?tab=commits" ], [ "visits", "Site visits", false, "/analytics?tab=visits" ],
               [ "mrr", "MRR", false, "/analytics?tab=mrr" ], [ "openstage", "Openstage views", false, "/analytics?tab=openstage" ] ])
  end

  it "makes a figure of a number that sits beside another, and marks the tabs Free does not open" do
    repo = create(:github_repo, user: user, full_name: "me/app", name: "app", site_source: "script", site_set_up_at: 3.days.ago)
    repo.site_visit_days.create!(day: 2.days.ago.to_date, visits: 30, visitors: 9)
    expect(view(tab: "visits")["tiles"].map { |tile| tile.values_at("key", "value", "figure") }).to eq([ [ "visits", "30", false ], [ "site_visitors", "9", true ] ])

    user.update!(pro: false)
    json = view
    expect(json["tabs"].map { |tab| [ tab["key"], tab["pro"] ] }).to eq([ [ "overview", false ], [ "commits", false ], [ "visits", false ], [ "mrr", true ], [ "openstage", true ] ])
    expect(json["rowsLabel"]).to eq("Projects")
  end

  it "sends the Commits tab's parts: Active days among the tiles, Last commit in the table, when the builder commits, and what's new" do
    create(:entry, user: user, repo_name: "me/app", entry_type: "milestone", source: "manual", title: "Launched", occurred_at: 1.day.ago)
    json = view(tab: "commits")

    expect(json["tiles"].map { |tile| tile.values_at("key", "value", "figure", "suffix") }).to eq([ [ "commits", "1", false, nil ], [ "active_days", "1", true, "of 30" ] ])
    expect(json["table"]["text"]).to eq("label" => "Last commit")
    expect(json["table"]["rows"].sole["text"]).to eq("2 days ago")
    hours = json["commits"]["hours"]
    expect(hours.pluck("name")).to eq(%w[Mon Tue Wed Thu Fri Sat Sun])
    expect(hours.flat_map { |day| day["cells"] }.reject { |cell| cell["step"].zero? }).to eq([ { "step" => 4, "title" => "Thu 12:00, 1 commit" } ])
    expect(hours[3]["cells"][12]["title"]).to eq("Thu 12:00, 1 commit")
    expect(json["commits"]["news"]).to eq([ { "id" => Entry.find_by!(title: "Launched").id, "date" => "Oct 23", "badge" => "milestone", "kind" => "Milestone",
                                              "colorClass" => "os-project-1", "title" => "Launched", "project" => "app" } ])
    expect(view.slice("commits")).to eq("commits" => nil)
    expect(view["table"]).not_to have_key("text")
  end

  it "steps each hour by quarters of the busiest, and says when nothing shipped" do
    { 9 => 4, 10 => 2, 11 => 3 }.each { |hour, count| count.times { create(:entry, user: user, repo_name: "me/app", occurred_at: 2.days.ago.change(hour: hour)) } }
    commits = view(tab: "commits")["commits"]

    expect(commits["hours"][3]["cells"][9..12].map { |cell| cell["step"] }).to eq([ 4, 2, 3, 1 ])
    expect(commits["hours"][3]["cells"][9]["title"]).to eq("Thu 09:00, 4 commits")
    expect(commits).to include("news" => [], "newsEmpty" => "Nothing shipped or published in the last 30 days.")
  end

  it "sends no table on a tab with no row, as MRR with no revenue" do
    expect(view(tab: "mrr")).to include("table" => nil, "tiles" => [])
  end

  it "lists ten projects with a colour, then how many it leaves out, with no link" do
    11.times { |i| create(:entry, user: user, repo_name: "me/p#{i}", occurred_at: 2.days.ago) }

    table = view(tab: "commits")["table"]
    expect(table["rows"].size).to eq(10)
    expect(table["more"]).to eq("text" => "2 more projects", "anchor" => nil)
  end

  it "sends where views of the builder's pages came from, their countries by name, the links followed with each page's dot, and the badge and embed, on Openstage views alone" do
    create(:profile_view, user: user, viewed_at: 2.days.ago, referrer: "news.ycombinator.com", country: "PT")
    create(:profile_view, user: user, viewed_at: 2.days.ago, referrer: "news.ycombinator.com", country: "PT")
    create(:profile_view, user: user, viewed_at: 2.days.ago, referrer: "x.com", country: "ZZ")
    user.project_clicks.create!(repo_name: "me/app", kind: "github", clicked_at: 1.day.ago)

    pages = view(tab: "openstage")["pages"]
    expect(pages["sources"]).to eq("rows" => [ { "label" => "Hacker News", "count" => "2", "width" => 100.0, "colorClass" => nil, "of" => nil, "other" => false },
                                               { "label" => "Twitter / X", "count" => "1", "width" => 50.0, "colorClass" => nil, "of" => nil, "other" => false } ], "empty" => nil)
    expect(pages["countries"]["rows"].pluck("label", "count")).to eq([ [ "Portugal", "2" ], [ "ZZ", "1" ] ])
    expect(pages["links"]["rows"].sole).to include("label" => "View on GitHub", "count" => "1", "colorClass" => "os-project-1", "of" => "app")
    expect(pages["badges"].first).to eq("label" => "README badge", "count" => "0", "sites" => "0 sites")
    expect(view(tab: "visits")["pages"]).to be_nil
  end

  it "sends the lists of the builder's websites on Site visits alone, each bar its share of the first, never under 1.5%, and Other with none" do
    repo = create(:github_repo, user: user, full_name: "me/app", name: "app", site_source: "script")
    { "github.com" => 400, SiteVisitCount::DIRECT => 1, SiteVisitCount::OTHER => 4 }.each { |host, count| repo.site_visit_counts.create!(kind: "source", value: host, count: count, day: 1.day.ago.to_date) }
    repo.site_visit_counts.create!(kind: "ref", value: "hn", count: 1_200, day: 1.day.ago.to_date)

    site = view(tab: "visits")["site"]
    expect(site["sources"]["rows"].map { |row| row.values_at("label", "count", "width", "other") })
      .to eq([ [ "GitHub", "400", 100.0, false ], [ "Direct", "1", 1.5, false ], [ "Other", "4", 0, true ] ])
    expect(site.slice("refs", "countries", "pages", "empty", "setup"))
      .to eq("refs" => { "rows" => [ { "label" => "hn", "count" => "1,200", "width" => 100.0, "colorClass" => nil, "of" => nil, "other" => false } ], "empty" => nil },
             "countries" => { "rows" => [], "empty" => "No countries in the last 30 days." }, "pages" => { "rows" => [], "empty" => "No page views in the last 30 days." },
             "empty" => nil, "setup" => nil)
    expect(view["site"]).to be_nil
  end

  it "gives each page the dot and name of its project as the table names it while pages of several count, and one with no row its full name" do
    projects = %w[me/app acme/app me/lib me/quiet].map { |full_name| create(:github_repo, user: user, full_name: full_name, name: full_name.split("/").last) }
    create(:entry, user: user, repo_name: "acme/app", occurred_at: 2.days.ago)
    create(:entry, user: user, repo_name: "me/lib", occurred_at: 2.days.ago)
    projects.each_with_index { |repo, i| repo.site_visit_counts.create!(kind: "page", value: "/", count: 4 - i, day: 1.day.ago.to_date) }
    json = view(tab: "visits")

    expect(json["table"]["rows"].pluck("name")).to eq([ "me/app", "acme/app", "lib" ])
    expect(json["site"]["pages"]["rows"].map { |page| page.values_at("label", "colorClass", "of") })
      .to eq([ [ "/", "os-project-1", "me/app" ], [ "/", "os-project-2", "acme/app" ], [ "/", "os-project-3", "lib" ], [ "/", nil, "me/quiet" ] ])
  end

  it "shows each path as its visitors read it, not as the browser escaped it, whole escapes only and no invisible characters" do
    repo = create(:github_repo, user: user, full_name: "me/app", name: "app", site_source: "script")
    { "/blog/s%C3%A3o-paulo-caf%C3%A9" => 3, "/docs/How%20To+Start" => 2, "/x%E2%80%AEgpj.exe" => 1, "/cut-in-an-escape-%E" => 1 }
      .each { |path, count| repo.site_visit_counts.create!(kind: "page", value: path, count: count, day: 1.day.ago.to_date) }

    expect(view(tab: "visits")["site"]["pages"]["rows"].pluck("label")).to eq([ "/blog/são-paulo-café", "/docs/How To+Start", "/cut-in-an-escape-", "/xgpj.exe" ])
  end

  it "says why the website lists are empty, with a link to set up a project's site visits while none of the projects in view counts them" do
    repo = create(:github_repo, user: user, full_name: "me/app", name: "app")

    expect(view(tab: "visits")["site"].slice("empty", "setup")).to eq("empty" => "None of the projects in view counts site visits.",
                                                                      "setup" => { "text" => "Set up app's site visits", "path" => "/projects/#{repo.id}/edit?site=open#site-visits" })
    repo.update!(site_source: "script")
    expect(view(tab: "visits", range: "90d")["site"].slice("empty", "setup")).to eq("empty" => "No site visits in the last 90 days.", "setup" => nil)
    expect(view(tab: "visits", range: "all")["site"]["empty"]).to eq("No site visits yet.")
  end

  it "puts Set up in the cells of the projects that count no site visits, on Overview and Site visits" do
    repo = create(:github_repo, user: user, full_name: "me/app", name: "app")
    cell = ->(json) { json["table"]["rows"].find { |row| row["key"] == "me/app" }["cells"].find { |each| each["key"] == "visits" } }

    expect(cell.call(view)).to include("value" => nil, "pick" => nil, "link" => { "text" => "Set up", "label" => "Set up app's site visits", "path" => "/projects/#{repo.id}/edit?site=open#site-visits" })
    expect(cell.call(view(tab: "visits"))["link"]["text"]).to eq("Set up")
  end

  it "compares nothing over all time, and a quiet list says so for all time" do
    json = view(range: "all")

    expect(json).to include("changesNote" => nil, "quiet" => "yet", "words" => "all time")
    expect(json["tiles"].sole["change"]).to be_nil
  end

  it "says nothing of changes when no value has one, as when the data starts inside the window" do
    expect(view(range: "12m")).to include("changesNote" => nil, "quiet" => "in the last 12 months")
  end
end
