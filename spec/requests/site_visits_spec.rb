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

  it "passes on the referrer the script sends as a page loads, and Cloudflare's country" do
    send_view({ p: "os_abc123", u: "https://shipnote.app/pricing?ref=hn", r: "https://news.ycombinator.com/" },
              headers: { "Origin" => "https://shipnote.app", "CF-IPCountry" => "PT" })

    expect(repo.site_visit_counts.pluck(:kind, :value)).to contain_exactly(
      [ "page", "/pricing" ], [ "source", "news.ycombinator.com" ], [ "ref", "hn" ], [ "country", "PT" ]
    )
  end

  it "takes a view sent without r for no source, and an empty r for Direct" do
    send_view({ p: "os_abc123", u: "https://shipnote.app/app?ref=hn" }, headers: { "CF-IPCountry" => "PT" })
    send_view({ p: "os_abc123", u: "https://shipnote.app/", r: "" }, headers: { "REMOTE_ADDR" => "203.0.113.8" })

    expect(repo.site_visit_counts.where(kind: %w[source ref]).pluck(:value)).to eq([ SiteVisitCount::DIRECT ])
  end

  it "answers the same way when nothing counts, and keeps nothing" do
    send_view({ p: "os_nope", u: "https://shipnote.app/" })
    expect(response).to have_http_status(:no_content)
    send_view(headers: { "Origin" => "https://copycat.example" })
    expect(response).to have_http_status(:no_content)
    post "/v", params: "not json", headers: browser
    expect(response).to have_http_status(:no_content)
    post "/v", params: { p: "os_abc123", u: "https://shipnote.app/", pad: "x" * 9000 }.to_json, headers: browser
    expect(response).to have_http_status(:no_content)
    send_view({ p: "os_abc123", u: "mailto://shipnote.app/" })
    expect(response).to have_http_status(:no_content)

    expect([ SiteVisitDay.count, SiteVisitCount.count ]).to eq([ 0, 0 ])
  end

  it "counts a page load whose forged referrer names no host, with no source" do
    send_view({ p: "os_abc123", u: "https://shipnote.app/pricing", r: "mailto:x" })

    expect(response).to have_http_status(:no_content)
    expect(repo.site_visit_counts.pluck(:kind, :value)).to eq([ [ "page", "/pricing" ] ])
  end

  it "counts a page load whose address and referrer are both long" do
    long = "https://news.example/#{'a' * 3000}"
    send_view({ p: "os_abc123", u: "https://shipnote.app/pricing?q=#{'b' * 3000}", r: long })

    expect(repo.site_visit_counts.pluck(:kind, :value)).to contain_exactly([ "page", "/pricing" ], [ "source", "news.example" ])
  end

  it "answers a paused project's script the same quiet way, and keeps nothing from it" do
    user.update!(pro: false)
    repo.update!(site_set_up_at: 3.days.ago)
    create(:github_repo, user: user, homepage: "https://lunchbox.example", site_source: "script", site_token: "os_first", site_set_up_at: 10.days.ago)

    send_view(headers: { "Origin" => "https://shipnote.app" })

    expect(response).to have_http_status(:no_content)
    expect([ response.body, response.cookies ]).to eq([ "", {} ])
    expect([ SiteVisitDay.count, SiteVisitor.count, SiteVisitCount.count ]).to eq([ 0, 0, 0 ])
  end

  it "counts nothing, answering as ever and logging no address, when a proxy's Client-IP is not in X-Forwarded-For" do
    io = StringIO.new
    log = ActiveSupport::Logger.new(io)
    Rails.logger.broadcast_to(log)
    send_view(headers: { "Client-IP" => "192.168.1.50", "X-Forwarded-For" => "198.51.100.23" })

    expect(response).to have_http_status(:no_content)
    expect(io.string).not_to include("198.51.100.23")
    expect([ SiteVisitDay.count, SiteVisitor.count, SiteVisitCount.count ]).to eq([ 0, 0, 0 ])
  ensure
    Rails.logger.stop_broadcasting_to(log)
  end

  it "serves the script that sends them" do
    script = Rails.public_path.join("v.js").read

    expect(script).to include('getAttribute("data-project")', "sendBeacon", "pushState", '"/v"', "document.referrer")
  end
end
