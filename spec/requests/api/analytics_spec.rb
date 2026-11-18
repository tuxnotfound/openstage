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

  it "answers 401 to a visitor who is not signed in, and to a Free builder 403 on the tabs Pro opens alone" do
    get "/api/analytics"
    expect(response).to have_http_status(:unauthorized)

    sign_in_as(create(:user, pro: false))
    [ nil, "commits", "visits" ].each do |tab|
      get "/api/analytics", params: { tab: tab }.compact
      expect(response).to have_http_status(:ok)
    end
    %w[mrr openstage].each do |tab|
      get "/api/analytics", params: { tab: tab }
      expect(response).to have_http_status(:forbidden)
    end
  end

  it "answers a Pro builder's view of a tab for the window, the numbers and the pages asked for, camelCased, to them alone" do
    create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "a", referrer: "news.ycombinator.com")
    # Before the window, so the builder's page has changes to explain.
    create(:profile_view, user: user, viewed_at: 100.days.ago, ip_hash: "z")
    user.project_views.create!(repo_name: "builder/app", viewed_at: 1.day.ago, ip_hash: "b")
    user.project_views.create!(repo_name: "builder/app", viewed_at: 1.day.ago, ip_hash: "c")
    sign_in_as(user)

    get "/api/analytics", params: { tab: "openstage", range: "90d", show: "views", projects: "builder/app" }

    expect(json).to include("tab" => "openstage", "range" => "90d", "words" => "last 90 days", "selected" => [ "builder/app" ], "drawn" => [ "views" ],
                            "defaultShow" => [ "views" ], "changesNote" => "Changes compare each value with the 90 days before.", "quiet" => "in the last 90 days")
    expect(json["tiles"].map { |tile| tile.values_at("key", "value", "figure") }).to eq([ [ "views", "2", false ], [ "visitors", "2", true ] ])
    expect(json["chart"]["ariaLabel"]).to eq("Views per week by page, last 90 days")
    expect(json["table"]["rows"].map { |row| row.values_at("key", "name", "on") }).to eq([ [ "page", "Your stage", false ], [ "builder/app", "app", true ] ])
    expect(json["table"]["rows"].first["cells"].find { |cell| cell["key"] == "visitors" }).to include("value" => "1", "change" => { "arrow" => "±", "text" => "0%", "up" => nil })
    expect(json["pages"]["sources"]["rows"].pluck("label", "count")).to eq([ [ "Direct", "2" ] ])
    expect(response.headers["Cache-Control"]).to include("private")
  end

  it "sends the tab's own lists alone, each its busiest eight, then Other" do
    repo = create(:github_repo, user: user, name: "app", full_name: "builder/app", site_source: "script", site_set_up_at: 3.days.ago)
    10.times { |i| repo.site_visit_counts.create!(kind: "page", value: "/p#{i}", count: 12 - i, day: 1.day.ago.to_date) }
    repo.site_visit_counts.create!(kind: "page", value: SiteVisitCount::OTHER, count: 2, day: 1.day.ago.to_date)
    create(:profile_view, user: user, viewed_at: 2.days.ago, referrer: "news.ycombinator.com")
    sign_in_as(user)

    get "/api/analytics", params: { tab: "visits" }
    rows = json["site"]["pages"]["rows"]
    expect(rows.map { |row| row.values_at("label", "count", "other") }).to eq((0..7).map { |i| [ "/p#{i}", (12 - i).to_s, false ] } + [ [ "Other", (4 + 3 + 2).to_s, true ] ])
    expect(json["pages"]).to be_nil

    get "/api/analytics", params: { tab: "openstage" }
    expect([ json["site"], json["pages"]["sources"]["rows"].pluck("label") ]).to eq([ nil, [ "Hacker News" ] ])

    get "/api/analytics"
    expect(json.values_at("site", "pages")).to eq([ nil, nil ])
  end

  it "reads analytics' old links: the one number drawn as metric, and the pages as pages[]" do
    create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "a")
    sign_in_as(user)

    get "/api/analytics", params: { metric: "views", pages: [ "page" ] }

    expect(json).to include("drawn" => [ "views" ], "selected" => [ "page" ], "range" => "30d")
  end
end
