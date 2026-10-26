require "rails_helper"

RSpec.describe "Site visits from Openstage's script", type: :request do
  let(:user) { create(:user, pro: true, time_zone: "Europe/Lisbon") }
  let!(:repo) do
    create(:github_repo, user: user, homepage: "https://shipnote.app", site_source: "script", site_token: "os_abc123")
  end
  let(:browser) { { "User-Agent" => "Mozilla/5.0 (Macintosh) Safari/605.1.15", "Content-Type" => "text/plain;charset=UTF-8" } }

  def send_view(body = { p: "os_abc123", u: "https://shipnote.app/pricing" }, headers: {})
    post "/v", params: body.to_json, headers: browser.merge(headers)
  end

  it "counts a page view from the project's website, as the script sends it" do
    expect { send_view(headers: { "Origin" => "https://www.shipnote.app" }) }.to change(SiteVisitDay, :count).by(1)

    expect(response).to have_http_status(:no_content)
    expect(response.cookies).to be_empty
    expect(repo.site_visit_days.last).to have_attributes(visits: 1, visitors: 1)
  end

  it "answers the same way when nothing counts, and keeps nothing" do
    send_view({ p: "os_nope", u: "https://shipnote.app/" })
    expect(response).to have_http_status(:no_content)
    send_view(headers: { "Origin" => "https://copycat.example" })
    expect(response).to have_http_status(:no_content)
    post "/v", params: "not json", headers: browser
    expect(response).to have_http_status(:no_content)

    expect(SiteVisitDay.count).to eq(0)
  end

  it "serves the script that sends them" do
    script = Rails.public_path.join("v.js").read

    expect(script).to include('getAttribute("data-project")', "sendBeacon", "pushState", '"/v"')
  end
end
