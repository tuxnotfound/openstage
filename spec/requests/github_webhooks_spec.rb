require "rails_helper"
require "support/github_app"

RSpec.describe "GitHub App webhooks", type: :request do
  include_context "with the GitHub App configured"

  let(:secret) { "webhook-secret" }
  let!(:user) { create(:user, github_uid: "123") }

  around do |example|
    Rails.configuration.x.github_app.webhook_secret = secret
    example.run
  ensure
    Rails.configuration.x.github_app.webhook_secret = nil
  end

  before { allow(GithubInstallationRefreshJob).to receive(:perform_later) }

  def deliver(event, payload, signed_with: secret)
    body = payload.to_json
    signature = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", signed_with, body)}"
    post github_webhook_path, params: body,
         headers: { "Content-Type" => "application/json", "X-GitHub-Event" => event, "X-Hub-Signature-256" => signature }
  end

  def installation_payload(account_id, action: "removed")
    { action: action, installation: { id: 7, account: { id: account_id, login: "someone", type: "User" } } }
  end

  it "refreshes the builder whose repo picks changed on GitHub" do
    deliver("installation_repositories", installation_payload(123))

    expect(response).to have_http_status(:accepted)
    expect(GithubInstallationRefreshJob).to have_received(:perform_later).with(user.id)
  end

  it "refreshes on an install or uninstall" do
    deliver("installation", installation_payload(123, action: "deleted"))
    expect(GithubInstallationRefreshJob).to have_received(:perform_later).with(user.id)
  end

  it "rejects a delivery not signed with the secret" do
    deliver("installation_repositories", installation_payload(123), signed_with: "forged")

    expect(response).to have_http_status(:unauthorized)
    expect(GithubInstallationRefreshJob).not_to have_received(:perform_later)
  end

  it "ignores an installation on an account that is no Openstage builder" do
    deliver("installation", installation_payload(555, action: "created"))

    expect(response).to have_http_status(:accepted)
    expect(GithubInstallationRefreshJob).not_to have_received(:perform_later)
  end

  it "ignores other events" do
    deliver("ping", { zen: "Keep it logically awesome.", hook_id: 1 })

    expect(response).to have_http_status(:accepted)
    expect(GithubInstallationRefreshJob).not_to have_received(:perform_later)
  end

  it "is off until a webhook secret is set" do
    Rails.configuration.x.github_app.webhook_secret = nil
    deliver("installation_repositories", installation_payload(123), signed_with: "anything")

    expect(response).to have_http_status(:not_found)
  end
end
