require "rails_helper"

RSpec.describe "Weekly email", type: :request do
  let(:user) { create(:user) }
  let(:token) { user.signed_id(purpose: :weekly_email) }

  # Mail scanners open every link, so the link in the mail only asks.
  it "asks on the link and turns the email off on the button, signed in or not" do
    get weekly_email_unsubscribe_path(token: token)
    expect(response).to have_http_status(:ok)
    expect(user.reload.weekly_email).to be(true)

    post weekly_email_unsubscribe_path, params: { token: token }
    expect(response).to redirect_to(root_path)
    expect(user.reload.weekly_email).to be(false)
  end

  # RFC 8058: the client POSTs with no session, so no CSRF token either.
  it "accepts a mail client's one-click POST" do
    ActionController::Base.allow_forgery_protection = true

    post weekly_email_unsubscribe_path(token: token), params: { "List-Unsubscribe" => "One-Click" }

    expect(user.reload.weekly_email).to be(false)
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  it "refuses a forged or foreign token" do
    get weekly_email_unsubscribe_path(token: "#{token}x")
    expect(response).to redirect_to(root_path)
    post weekly_email_unsubscribe_path, params: { token: "#{token}x" }
    post weekly_email_unsubscribe_path, params: { token: user.signed_id(purpose: :something_else) }

    expect(user.reload.weekly_email).to be(true)
  end

  it "turns back on from Settings" do
    user.update!(weekly_email: false)
    sign_in_as(user)

    patch settings_path, params: { user: { weekly_email: "1" } }

    expect(user.reload.weekly_email).to be(true)
  end

  it "sends links to the old recap picker and week card, from emails already sent, to the dashboard" do
    [ "/recap?from=weekly", "/week?from=weekly", "/week/2026-W43" ].each do |path|
      get path

      expect(response).to redirect_to("/dashboard")
    end
  end
end
