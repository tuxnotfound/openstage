require "rails_helper"

RSpec.describe "Api::Analytics", type: :request do
  let(:user) { create(:user, pro: true, username: "builder") }

  before do
    travel_to Time.utc(2026, 10, 24, 12)
    create(:entry, user: user, repo_name: "builder/app")
  end

  def json
    response.parsed_body
  end

  it "answers 401 to a visitor who is not signed in, and 403 to a free builder" do
    get "/api/analytics"
    expect(response).to have_http_status(:unauthorized)

    sign_in_as(create(:user, pro: false))
    get "/api/analytics"
    expect(response).to have_http_status(:forbidden)
  end

  it "answers a Pro builder's view for the window, the numbers and the pages asked for, camelCased, to them alone" do
    create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "a", referrer: "news.ycombinator.com")
    # Before the window, so the builder's page has changes to explain.
    create(:profile_view, user: user, viewed_at: 100.days.ago, ip_hash: "z")
    user.project_views.create!(repo_name: "builder/app", viewed_at: 1.day.ago, ip_hash: "b")
    user.project_views.create!(repo_name: "builder/app", viewed_at: 1.day.ago, ip_hash: "c")
    sign_in_as(user)

    get "/api/analytics", params: { range: "90d", show: "views", projects: "builder/app" }

    expect(json).to include("range" => "90d", "words" => "last 90 days", "selected" => [ "builder/app" ], "drawn" => [ "views" ], "defaultShow" => [ "commits" ],
                            "changesNote" => "Changes compare each value with the 90 days before.", "quiet" => "in the last 90 days")
    expect(json["numbers"].map { |number| number.values_at("key", "group", "value") })
      .to eq([ [ "commits", "On GitHub", "1" ], [ "views", "On Openstage", "2" ] ])
    expect(json["chart"]["ariaLabel"]).to eq("Views per week by page, last 90 days")
    expect(json["table"]["rows"].map { |row| row.values_at("key", "name", "on") }).to eq([ [ "page", "Your stage", false ], [ "builder/app", "app", true ] ])
    expect(json["table"]["rows"].first["cells"].find { |cell| cell["key"] == "visitors" }).to include("value" => "1", "change" => { "arrow" => "±", "text" => "0%", "up" => nil })
    expect(json["sources"]).to eq([ { "label" => "Direct", "count" => "2", "width" => 100 } ])
    expect(response.headers["Cache-Control"]).to include("private")
  end

  it "sends both sets of panels in one view, whichever the page's URL names, each its busiest, then Other" do
    repo = create(:github_repo, user: user, name: "app", full_name: "builder/app", site_source: "script", site_set_up_at: 3.days.ago)
    7.times { |i| repo.site_visit_counts.create!(kind: "page", value: "/p#{i}", count: 10 - i, day: 1.day.ago.to_date) }
    repo.site_visit_counts.create!(kind: "page", value: SiteVisitCount::OTHER, count: 2, day: 1.day.ago.to_date)
    repo.site_visit_counts.create!(kind: "source", value: SiteVisitCount::DIRECT, count: 4, day: 1.day.ago.to_date)
    repo.site_visit_counts.create!(kind: "source", value: SiteVisitCount::OTHER, count: 8, day: 1.day.ago.to_date)
    create(:profile_view, user: user, viewed_at: 2.days.ago, referrer: "news.ycombinator.com")
    sign_in_as(user)

    get "/api/analytics", params: { panels: "openstage" }

    expect(json["sources"]).to eq([ { "label" => "Hacker News", "count" => "1", "width" => 100 } ])
    expect(json["websites"]).to eq("sources" => [ { "label" => "Direct", "count" => "4", "width" => 50 }, { "label" => "Other", "count" => "8", "width" => 100 } ],
                                   "refs" => [], "countries" => [],
                                   "pages" => (0..5).map { |i| { "label" => "/p#{i}", "count" => (10 - i).to_s, "project" => nil } } +
                                              [ { "label" => "Other", "count" => "6", "project" => nil } ],
                                   "empty" => nil, "setup" => nil)
    get "/api/analytics"
    expect(json["websites"]["pages"].size).to eq(7)
  end

  it "reads analytics' old links: the one number drawn as metric, and the pages as pages[]" do
    create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "a")
    sign_in_as(user)

    get "/api/analytics", params: { metric: "views", pages: [ "page" ] }

    expect(json).to include("drawn" => [ "views" ], "selected" => [ "page" ], "range" => "30d")
  end
end
