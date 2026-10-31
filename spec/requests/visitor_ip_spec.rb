require "rails_helper"

# Requests reach the app through Cloudflare, then Render's own proxy, so the
# visitor is the address before Cloudflare's edge in X-Forwarded-For.
RSpec.describe "Counting a visitor by their own address", type: :request do
  let!(:user) { create(:user, username: "builder") }
  let(:browser) { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }

  def visit_from(forwarded_for)
    get "/builder", headers: { "HTTP_USER_AGENT" => browser, "REMOTE_ADDR" => "10.0.0.5", "HTTP_X_FORWARDED_FOR" => forwarded_for }
  end

  it "looks past a Cloudflare edge to the visitor" do
    visit_from("203.0.113.7, 172.70.1.1")
    visit_from("203.0.113.7, 104.22.9.9")

    expect(user.profile_views.pluck(:ip_hash)).to eq([ VisitorHash.of("203.0.113.7") ] * 2)
  end

  it "stops at the first address that is not Cloudflare's, so a forged header cannot pick one" do
    visit_from("203.0.113.7, 198.51.100.9")

    expect(user.profile_views.last.ip_hash).to eq(VisitorHash.of("198.51.100.9"))
  end

  it "keeps the address hashed with the day and a key, never the unkeyed hash" do
    visit_from("203.0.113.7, 172.70.1.1")

    expect(user.profile_views.last.ip_hash).not_to eq(Digest::SHA256.hexdigest("203.0.113.7#{Date.current}"))
  end
end
