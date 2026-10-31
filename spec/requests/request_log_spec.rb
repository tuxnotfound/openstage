require "rails_helper"

# Openstage's request log keeps no visitor's IP address
# (config/initializers/request_log.rb, and cloudflare_proxies.rb for a
# Client-IP header).
RSpec.describe "The request log", type: :request do
  let(:io) { StringIO.new }
  let(:visitor) { { "User-Agent" => "Mozilla/5.0 (Macintosh) Safari/605.1.15", "REMOTE_ADDR" => "203.0.113.99" } }
  # Behind Cloudflare, with a Client-IP header that X-Forwarded-For does not
  # name, as some proxies add and anyone can send.
  let(:visitor_with_client_ip) { visitor.merge("REMOTE_ADDR" => "10.0.0.5", "X-Forwarded-For" => "198.51.100.77, 172.70.1.1", "Client-IP" => "192.0.2.99") }

  # As production.rb sets it up: Ruby's formatter, tagged, at info.
  def production_logger
    logger = ActiveSupport::Logger.new(io, level: :info).tap { |plain| plain.formatter = ::Logger::Formatter.new }
    ActiveSupport::TaggedLogging.new(logger)
  end

  # The app logs to production's logger alone while an example runs: a second
  # tagged logger beside the test log would make the broadcast run each
  # request twice.
  around do |example|
    logger = production_logger
    test_loggers = Rails.logger.broadcasts.dup
    test_loggers.each { |test_logger| Rails.logger.stop_broadcasting_to(test_logger) }
    Rails.logger.broadcast_to(logger)
    example.run
  ensure
    Rails.logger.stop_broadcasting_to(logger)
    Rails.logger.broadcast_to(*test_loggers)
  end

  def send_view(headers = visitor)
    post "/v", params: { p: "os_abc123", u: "https://shipnote.app/" }.to_json, headers: headers.merge("Content-Type" => "text/plain;charset=UTF-8")
  end

  it "starts each request's lines without the visitor's address" do
    get "/privacy", headers: visitor

    expect(io.string).to include(%(Started GET "/privacy" at ))
    expect(io.string).not_to include("203.0.113.99")
  end

  it "counts a visit that also carries a Client-IP under the forwarded address, and logs neither" do
    create(:user, username: "builder")
    get "/builder", headers: visitor_with_client_ip

    expect(response).to have_http_status(:ok)
    expect(io.string).not_to include("198.51.100.77", "192.0.2.99")
    expect(ProfileView.sole.ip_hash).to eq(VisitorHash.of("198.51.100.77"))
  end

  it "leaves /cable to the app's own routes: Action Cable's connections log the address on their own" do
    get "/cable", headers: visitor

    expect(io.string).to include(%(Started GET "/cable" at ))
    expect(io.string).not_to include("203.0.113.99", "WebSocket")
  end

  it "tags that line with the request's id, as production does" do
    logger = RequestLogger.new(->(_env) { [ 204, {}, [] ] }, [ :request_id ])
    logger.call(Rack::MockRequest.env_for("/builder", "REMOTE_ADDR" => "203.0.113.99", "action_dispatch.request_id" => "req-42"))

    expect(io.string).to match(/INFO -- : \[req-42\] Started GET "\/builder" at /)
    expect(io.string).not_to include("203.0.113.99")
  end

  it "logs nothing below a warning of the page views the script sends, and counts them once" do
    repo = create(:github_repo, user: create(:user, pro: true), homepage: "https://shipnote.app", site_source: "script", site_token: "os_abc123")
    send_view

    expect(response).to have_http_status(:no_content)
    expect(io.string).to eq("")
    expect(repo.site_visit_days.sole.visits).to eq(1)
  end

  it "counts a page view that also carries a Client-IP, and logs nothing" do
    repo = create(:github_repo, user: create(:user, pro: true), homepage: "https://shipnote.app", site_source: "script", site_token: "os_abc123")
    send_view(visitor_with_client_ip)

    expect(response).to have_http_status(:no_content)
    expect(io.string).to eq("")
    expect(repo.site_visit_days.sole.visits).to eq(1)
  end

  it "still logs a page view's error" do
    allow(SiteVisits::RecordService).to receive(:new).and_raise(ActiveRecord::RecordNotFound, "No such project")
    send_view

    expect(io.string).to include("ActiveRecord::RecordNotFound (No such project)")
    expect(io.string).not_to include("Started", "203.0.113.99")
  end
end
