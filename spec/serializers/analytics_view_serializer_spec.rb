require "rails_helper"

RSpec.describe AnalyticsViewSerializer do
  let(:user) { create(:user, pro: true) }

  before do
    travel_to Time.utc(2026, 10, 24, 12)
    create(:entry, user: user, repo_name: "me/app", occurred_at: 2.days.ago)
    create(:entry, user: user, repo_name: "me/app", occurred_at: 40.days.ago)
  end

  def view(**options)
    described_class.new(Analytics::ReportService.new(user: user, **options).tap(&:call!)).as_json
  end

  it "sends the chart filter with a change on every toggle and every cell, and what the changes compare with" do
    json = view

    expect(json["numbers"].sole).to include("key" => "commits", "group" => "On GitHub", "change" => { "arrow" => "±", "text" => "0%", "up" => nil })
    expect(json["table"]["rows"].map { |row| [ row["name"], row["cells"].sole.slice("value", "change") ] })
      .to eq([ [ "Your stage", { "value" => nil, "change" => nil } ], [ "app", { "value" => "1", "change" => { "arrow" => "±", "text" => "0%", "up" => nil } } ] ])
    expect(json["table"]["rows"].pluck("colorClass")).to eq(%w[os-project-none os-project-1])
    expect(json).to include("changesNote" => "Changes compare each value with the 30 days before.", "quiet" => "in the last 30 days")
  end

  it "sends where visitors came from, the links they followed and the badge and embed" do
    create(:profile_view, user: user, viewed_at: 2.days.ago, referrer: "news.ycombinator.com", country: "PT")
    create(:profile_view, user: user, viewed_at: 2.days.ago, referrer: "news.ycombinator.com", country: "PT")
    user.project_clicks.create!(repo_name: "me/app", kind: "github", clicked_at: 1.day.ago)

    json = view

    expect(json["sources"]).to eq([ { "label" => "Hacker News", "count" => "2", "width" => 100 } ])
    expect(json["countries"]).to eq([ { "label" => "PT", "count" => "2" } ])
    expect(json["links"]).to eq([ { "title" => "View on GitHub", "page" => "app", "count" => "1" } ])
    expect(json["badges"].first).to eq("label" => "README badge", "count" => "0", "sites" => "0 sites")
  end

  it "sends the panels of the builder's websites, each bar as wide as its share of the busiest, the cap's Other row too" do
    repo = create(:github_repo, user: user, full_name: "me/app", name: "app", site_source: "script")
    { "github.com" => 2, SiteVisitCount::DIRECT => 1, SiteVisitCount::OTHER => 4 }.each { |host, count| repo.site_visit_counts.create!(kind: "source", value: host, count: count, day: 1.day.ago.to_date) }
    repo.site_visit_counts.create!(kind: "ref", value: "hn", count: 1_200, day: 1.day.ago.to_date)

    expect(view["websites"]).to eq("sources" => [ { "label" => "GitHub", "count" => "2", "width" => 50 }, { "label" => "Direct", "count" => "1", "width" => 25 },
                                                  { "label" => "Other", "count" => "4", "width" => 100 } ],
                                   "refs" => [ { "label" => "hn", "count" => "1,200" } ], "countries" => [], "pages" => [], "empty" => nil, "setup" => nil)
  end

  it "says why the website panels are empty, with a link to set up the first project's site visits while none of the projects in view counts them" do
    repo = create(:github_repo, user: user, full_name: "me/app", name: "app")

    expect(view["websites"].slice("empty", "setup")).to eq("empty" => "None of the projects in view counts site visits.",
                                                           "setup" => { "text" => "Set up app's site visits", "path" => "/projects/#{repo.id}/edit?site=open#site-visits" })
    repo.update!(site_source: "script")
    expect(view(range: "90d")["websites"].slice("empty", "setup")).to eq("empty" => "No site visits in the last 90 days.", "setup" => nil)
    expect(view(range: "all")["websites"]["empty"]).to eq("No site visits yet.")
  end

  it "compares nothing over all time, and a quiet panel says so for all time" do
    json = view(range: "all")

    expect(json).to include("changesNote" => nil, "quiet" => "yet", "words" => "all time")
    expect(json["numbers"].sole["change"]).to be_nil
  end

  it "says nothing of changes when no value has one, as when the data starts inside the window" do
    expect(view(range: "12m")).to include("changesNote" => nil, "quiet" => "in the last 12 months")
  end
end
