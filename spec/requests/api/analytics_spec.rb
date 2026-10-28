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
    user.project_views.create!(repo_name: "builder/app", viewed_at: 1.day.ago, ip_hash: "b")
    user.project_views.create!(repo_name: "builder/app", viewed_at: 1.day.ago, ip_hash: "c")
    sign_in_as(user)

    get "/api/analytics", params: { range: "90d", show: "views", projects: "builder/app" }

    expect(json).to include("range" => "90d", "words" => "last 90 days", "selected" => [ "builder/app" ], "drawn" => [ "views" ], "defaultShow" => [ "commits" ],
                            "changesNote" => "Changes compare each value with the 90 days before.", "quiet" => "in the last 90 days")
    expect(json["numbers"].map { |number| number.values_at("key", "group", "value") })
      .to eq([ [ "commits", "On GitHub", "1" ], [ "visitors", "On Openstage", "2" ], [ "views", "On Openstage", "2" ] ])
    expect(json["chart"]["ariaLabel"]).to eq("Views per week by page, last 90 days")
    expect(json["table"]["rows"].map { |row| row.values_at("repo", "name", "on") }).to eq([ [ "page", "Your page", false ], [ "builder/app", "app", true ] ])
    expect(json["sources"]).to eq([ { "label" => "Direct", "count" => "2", "width" => 100 } ])
    expect(response.headers["Cache-Control"]).to include("private")
  end

  it "reads analytics' old links: the one number drawn as metric, and the pages as pages[]" do
    create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "a")
    sign_in_as(user)

    get "/api/analytics", params: { metric: "views", pages: [ "page" ] }

    expect(json).to include("drawn" => [ "views" ], "selected" => [ "page" ], "range" => "30d")
  end
end
