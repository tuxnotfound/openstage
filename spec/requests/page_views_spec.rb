require "rails_helper"

RSpec.describe "Views Openstage's pages send from the browser", type: :request do
  let!(:user) { create(:user, username: "builder") }
  let(:browser) { { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh) Safari/605.1.15" } }

  def send_view(ticket, headers = {})
    post "/pv", params: { t: ticket }, headers: browser.merge(headers)
  end

  it "counts a view of the builder's stage, with where the visitor came from" do
    ticket = PageViewTicket.issue(user: user, referrer: "news.ycombinator.com")

    expect { send_view(ticket, "CF-IPCountry" => "PT", "REMOTE_ADDR" => "203.0.113.7") }.to change(user.profile_views, :count).by(1)
    expect(response).to have_http_status(:no_content)
    expect(response.cookies).to be_empty
    expect(user.profile_views.last).to have_attributes(referrer: "news.ycombinator.com", country: "PT", ip_hash: VisitorHash.of("203.0.113.7"))
  end

  it "counts a project page's view as that project's" do
    ticket = PageViewTicket.issue(user: user, referrer: nil, repo_name: "builder/side.app")

    expect { send_view(ticket) }.to change(user.project_views, :count).by(1)
    expect(user.project_views.last).to have_attributes(repo_name: "builder/side.app", referrer: nil)
    expect(user.profile_views.count).to eq(0)
  end

  it "answers the same way when nothing counts, and keeps nothing" do
    stale = PageViewTicket.issue(user: user, referrer: nil)
    travel(PageViewTicket::LIFETIME + 1.minute) { send_view(stale) }
    expect(response).to have_http_status(:no_content)

    send_view("forged")
    expect(response).to have_http_status(:no_content)

    send_view(PageViewTicket.issue(user: user, referrer: nil), "HTTP_USER_AGENT" => "Googlebot/2.1 (+http://www.google.com/bot.html)")
    expect(response).to have_http_status(:no_content)

    post "/pv", headers: browser
    expect(response).to have_http_status(:no_content)

    expect(ProfileView.count + ProjectView.count).to eq(0)
  end
end
