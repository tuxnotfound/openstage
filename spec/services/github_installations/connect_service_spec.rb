require "rails_helper"

RSpec.describe GithubInstallations::ConnectService do
  let(:user) { create(:user, github_uid: "123", github_username: "tuxnotfound") }
  let(:own) { { id: 7, account_id: 123, account_login: "tuxnotfound" } }

  def connect(installation_id: "7", code: "abc", as: user)
    described_class.new(user: as, code: code, installation_id: installation_id)
  end

  before do
    allow(GithubOauthGateway).to receive(:user_token).with("abc").and_return("ghu_user")
    allow(GithubAppGateway).to receive(:installations).with("ghu_user").and_return([ own ])
    allow(GithubSyncJob).to receive(:perform_later)
  end

  it "stores an installation on the builder's own account and syncs" do
    service = connect

    expect(service.call).to be(true)
    expect(user.reload.github_installation_id).to eq(7)
    expect(GithubSyncJob).to have_received(:perform_later).with(user.id)
  end

  it "requires a user" do
    expect(connect(as: nil).call).to be(false)
  end

  it "refuses a callback without an installation, before calling GitHub" do
    service = connect(installation_id: nil)

    expect(service.call).to be(false)
    expect(service.errors.full_messages.to_sentence).to include("did not send an installation")
    expect(GithubOauthGateway).not_to have_received(:user_token)
  end

  # The installation_id is a query param: an edited one must not attach
  # somebody else's installation.
  it "refuses an installation the builder's token does not list" do
    service = connect(installation_id: "99")

    expect(service.call).to be(false)
    expect(service.errors.full_messages.to_sentence).to include("did not list that installation")
    expect(user.reload.github_installation_id).to be_nil
  end

  it "refuses an installation on another account" do
    allow(GithubAppGateway).to receive(:installations)
      .and_return([ { id: 7, account_id: 555, account_login: "acme" } ])
    service = connect

    expect(service.call).to be(false)
    expect(service.errors.full_messages.to_sentence).to include("installed on acme, not on your account tuxnotfound")
    expect(user.reload.github_installation_id).to be_nil
    expect(GithubSyncJob).not_to have_received(:perform_later)
  end

  it "fails cleanly when GitHub refuses the code" do
    allow(GithubOauthGateway).to receive(:user_token).and_raise(ApplicationGateway::ClientError.new("expired"))
    service = connect

    expect(service.call).to be(false)
    expect(service.errors.full_messages.to_sentence).to include("did not confirm the connection")
  end
end
