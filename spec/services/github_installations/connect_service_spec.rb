require "rails_helper"

RSpec.describe GithubInstallations::ConnectService do
  let(:user) { create(:user, github_uid: "123", github_username: "tuxnotfound") }

  before do
    allow(GithubAppGateway).to receive(:user_installation).with("tuxnotfound").and_return(id: 7, account_id: 123)
    allow(GithubSyncJob).to receive(:perform_later)
  end

  it "stores the installation on the builder's own account and syncs" do
    expect(described_class.new(user: user).call).to be(true)
    expect(user.reload.github_installation_id).to eq(7)
    expect(GithubSyncJob).to have_received(:perform_later).with(user.id)
  end

  it "requires a user" do
    expect(described_class.new(user: nil).call).to be(false)
    expect(GithubAppGateway).not_to have_received(:user_installation)
  end

  it "says so when the App is not installed on the account" do
    allow(GithubAppGateway).to receive(:user_installation).and_raise(ApplicationGateway::NotFound.new(status: 404))
    service = described_class.new(user: user)

    expect(service.call).to be(false)
    expect(service.errors.full_messages.to_sentence).to include("not installed on your GitHub account")
    expect(user.reload.github_installation_id).to be_nil
  end

  # github_username is only refreshed at sign-in. If the builder renamed on
  # GitHub and someone else took the old name, that is not their installation.
  it "refuses an installation on an account that is no longer the builder's" do
    allow(GithubAppGateway).to receive(:user_installation).and_return(id: 9, account_id: 555)
    service = described_class.new(user: user)

    expect(service.call).to be(false)
    expect(service.errors.full_messages.to_sentence).to include("GitHub username has changed")
    expect(user.reload.github_installation_id).to be_nil
    expect(GithubSyncJob).not_to have_received(:perform_later)
  end
end
