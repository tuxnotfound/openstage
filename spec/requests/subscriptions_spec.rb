require "rails_helper"

RSpec.describe "Email subscribe", type: :request do
  let!(:builder) { create(:user, username: "builder", display_name: "Bea") }
  let(:browser)  { { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh) Safari/605.1.15" } }

  describe "the box on the public page" do
    it "is shown to visitors and never shows a count" do
      3.times { |i| builder.subscriptions.create!(email: "r#{i}@example.com", confirmed_at: Time.current) }

      get "/builder"
      expect(response.body).to include("data-subscribe-box")
      expect(response.body).not_to match(/3 subscribers/i)
    end

    it "is hidden from the owner" do
      sign_in_as(builder)
      get "/builder"
      expect(response.body).not_to include("data-subscribe-box")
    end
  end

  describe "POST /:username/subscribe" do
    it "creates a pending subscription and sends one confirmation" do
      expect {
        post "/builder/subscribe", params: { email: " Reader@Example.com " }, headers: browser
      }.to change { builder.subscriptions.pending.count }.by(1)
        .and have_enqueued_mail(SubscriptionMailer, :confirm)

      expect(builder.subscriptions.last.email).to eq("reader@example.com")
      expect(response).to redirect_to("/builder")
      expect(flash[:notice]).to match(/check your inbox/i)
    end

    it "does not resend within ten minutes, and says the same thing either way" do
      post "/builder/subscribe", params: { email: "reader@example.com" }, headers: browser
      expect {
        post "/builder/subscribe", params: { email: "reader@example.com" }, headers: browser
      }.not_to have_enqueued_mail(SubscriptionMailer, :confirm)
      expect(flash[:notice]).to match(/check your inbox/i)
    end

    it "answers a confirmed address exactly like a new one" do
      builder.subscriptions.create!(email: "reader@example.com", confirmed_at: Time.current)
      expect {
        post "/builder/subscribe", params: { email: "reader@example.com" }, headers: browser
      }.not_to have_enqueued_mail(SubscriptionMailer, :confirm)
      expect(flash[:notice]).to match(/check your inbox/i)
    end

    it "rejects a non-address" do
      expect {
        post "/builder/subscribe", params: { email: "not an email" }, headers: browser
      }.not_to change { Subscription.count }
      expect(flash[:alert]).to be_present
    end

    it "drops a filled honeypot and crawlers silently" do
      expect {
        post "/builder/subscribe", params: { email: "bot@example.com", website: "http://spam" }, headers: browser
        post "/builder/subscribe", params: { email: "bot2@example.com" }, headers: { "HTTP_USER_AGENT" => "GPTBot/1.0" }
      }.not_to change { Subscription.count }
    end

    it "renders the page, flash and all, when Turbo follows the redirect" do
      turbo = browser.merge("HTTP_ACCEPT" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml")

      post "/builder/subscribe", params: { email: "reader@example.com" }, headers: turbo
      follow_redirect!

      expect(response.media_type).to eq("text/html")
      expect(response.body).to include("Check your inbox")
      expect(response.body).not_to include("<turbo-stream")
    end

    it "404s for an unknown builder" do
      post "/nobody-here/subscribe", params: { email: "reader@example.com" }, headers: browser
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "confirm and unsubscribe" do
    let(:sub) { builder.subscriptions.create!(email: "reader@example.com") }

    it "confirms from the token and lands on the builder's page" do
      get "/subscriptions/#{sub.token}/confirm"
      expect(sub.reload).to be_confirmed
      expect(response).to redirect_to("/builder")
    end

    it "unsubscribes in one click and forgets the address" do
      sub.confirm!
      expect { get "/subscriptions/#{sub.token}/unsubscribe" }.to change { Subscription.count }.by(-1)
      expect(response).to redirect_to("/builder")

      post "/subscriptions/#{sub.token}/unsubscribe"
      expect(response).to redirect_to(root_path)
    end

    it "shrugs at a dead token" do
      get "/subscriptions/nope/confirm"
      expect(response).to redirect_to(root_path)
    end

    it "puts a List-Unsubscribe header and both links in the mail" do
      mail = SubscriptionMailer.confirm(sub)
      expect(mail.header["List-Unsubscribe"].value).to include(sub.token)
      expect(mail.text_part.body.to_s).to include("/subscriptions/#{sub.token}/confirm")
      expect(mail.html_part.body.to_s).to include("/subscriptions/#{sub.token}/unsubscribe")
    end
  end

  describe "the builder's side" do
    before do
      builder.subscriptions.create!(email: "a@example.com", confirmed_at: 2.days.ago)
      builder.subscriptions.create!(email: "b@example.com", confirmed_at: 1.day.ago)
      builder.subscriptions.create!(email: "pending@example.com")
      sign_in_as(builder)
    end

    it "shows a free builder how many confirmed, not who" do
      get "/dashboard"
      expect(response.body).to include('data-subscribers data-count="2"')
      expect(response.body).to include("2 subscribers")
      expect(response.body).not_to include("a@example.com")
      expect(response.body).to include("See who, with Pro")
    end

    it "shows a Pro builder the list" do
      builder.update!(pro: true)
      get "/dashboard"
      expect(response.body).to include("a@example.com")
      expect(response.body).to include("b@example.com")
      expect(response.body).not_to include("pending@example.com")
    end
  end

  it "reserves the route prefix as a username" do
    expect(User::RESERVED_USERNAMES).to include("subscriptions")
  end
end
