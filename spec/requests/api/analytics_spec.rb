require "rails_helper"

RSpec.describe "Api::Analytics", type: :request do
  let(:user) { create(:user, pro: true, username: "builder") }

  before do
    travel_to Time.utc(2026, 10, 24, 12)
    create(:entry, user: user, repo_name: "builder/app")
  end

  it "answers 401 to a visitor who is not signed in, and 403 to a free builder" do
    get "/api/analytics"
    expect(response).to have_http_status(:unauthorized)

    sign_in_as(create(:user, pro: false))
    get "/api/analytics"
    expect(response).to have_http_status(:forbidden)
  end

  it "answers a Pro builder's view for the window, pages and number asked for" do
    create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "a", referrer: "news.ycombinator.com")
    user.project_views.create!(repo_name: "builder/app", viewed_at: 1.day.ago, ip_hash: "b")
    user.project_views.create!(repo_name: "builder/app", viewed_at: 1.day.ago, ip_hash: "c")
    sign_in_as(user)

    get "/api/analytics", params: { range: "7d", metric: "views", pages: [ "builder/app" ] }

    json = response.parsed_body
    expect(json).to include("range" => "7d", "metric" => "views", "selected" => [ "builder/app" ], "total" => "2", "scope" => "app", "label" => "Views",
                                "changeLabel" => "vs 7 days before")
    expect(json["rows"].map { |row| row["key"] }).to eq([ "builder/app" ])
    expect(json["chart"]["ariaLabel"]).to eq("Views per day by page, last 7 days")
    expect(json["tabs"].map { |tab| [ tab["metric"], tab["group"] ] }).to eq([ %w[commits On\ GitHub], %w[site On\ your\ websites], %w[visitors On\ Openstage],
                                                                           %w[views On\ Openstage], %w[follows On\ Openstage], %w[clicks On\ Openstage] ])
  end
end
