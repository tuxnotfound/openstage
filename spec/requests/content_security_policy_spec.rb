require "rails_helper"

RSpec.describe "Content Security Policy", type: :request do
  it "is enforced, not report-only" do
    get "/"
    expect(response.headers["Content-Security-Policy"]).to be_present
    expect(response.headers["Content-Security-Policy-Report-Only"]).to be_nil
  end

  it "allows scripts only from our origin, this response's nonce, and analytics" do
    get "/"
    csp = response.headers["Content-Security-Policy"]

    expect(csp).to match(/script-src 'self' https:\/\/cloud\.umami\.is 'nonce-[^']+'/)
    expect(csp).to include("object-src 'none'")
    expect(csp).to include("base-uri 'self'")
    expect(csp).to include("frame-ancestors 'self'")
    expect(csp).not_to match(/script-src[^;]*unsafe-inline/)
  end

  it "stamps the importmap with the same nonce, so our own JavaScript still runs" do
    get "/"
    nonce = response.headers["Content-Security-Policy"][/'nonce-([^']+)'/, 1]

    expect(response.body).to include(%(<script type="importmap" data-turbo-track="reload" nonce="#{nonce}"))
    expect(response.body.scan(%(nonce="#{nonce}")).size).to be >= 2
  end

  it "issues a different nonce on every response" do
    get "/"
    first = response.headers["Content-Security-Policy"][/'nonce-([^']+)'/, 1]
    get "/"
    expect(response.headers["Content-Security-Policy"][/'nonce-([^']+)'/, 1]).not_to eq(first)
  end

  it "leaves no inline event handler in any view, since the policy would block it" do
    offenders = Dir[Rails.root.join("app/views/**/*.erb")].flat_map do |path|
      File.readlines(path).each_with_index.filter_map do |line, i|
        "#{path.delete_prefix("#{Rails.root}/")}:#{i + 1}" if line.match?(/\son[a-z]+=["']/)
      end
    end

    expect(offenders).to be_empty
  end
end
