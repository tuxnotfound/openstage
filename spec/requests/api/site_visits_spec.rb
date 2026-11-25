require "rails_helper"

RSpec.describe "Where a project's site visits stand, as Set up site visits asks", type: :request do
  let(:user) { create(:user, pro: true, time_zone: "Europe/Lisbon") }
  let!(:repo) do
    create(:github_repo, user: user, name: "shipnote", homepage: "https://shipnote.app", site_source: "script", site_token: "os_abc123",
                         site_set_up_at: 1.hour.ago)
  end

  it "answers the wait, then the first visit once one counts, with no reload of the page" do
    travel_to Time.utc(2026, 11, 25, 14, 2)
    sign_in_as(user)

    get "/api/site_visits/#{repo.id}"
    expect(response.parsed_body).to eq("step" => "line", "firstVisit" => nil, "seen" => true)

    post "/v", params: { p: "os_abc123", u: "https://shipnote.app/" }.to_json,
               headers: { "User-Agent" => "Mozilla/5.0 (Macintosh) Safari/605.1.15", "Content-Type" => "text/plain;charset=UTF-8" }
    get "/api/site_visits/#{repo.id}"
    expect(response.parsed_body).to eq("step" => "done", "firstVisit" => "First visit received today at 14:02", "seen" => true)
  end

  it "answers no one signed out, and nobody about another builder's project" do
    get "/api/site_visits/#{repo.id}"
    expect(response).to have_http_status(:unauthorized)

    sign_in_as(create(:user))
    get "/api/site_visits/#{repo.id}"
    expect(response).to have_http_status(:not_found)
  end
end
