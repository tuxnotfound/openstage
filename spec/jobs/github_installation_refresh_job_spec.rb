require "rails_helper"

RSpec.describe GithubInstallationRefreshJob, type: :job do
  let(:user) { create(:user) }

  it "refreshes the builder's installation" do
    refresh = instance_double(GithubInstallations::RefreshService, call!: true)
    allow(GithubInstallations::RefreshService).to receive(:new).with(user: user).and_return(refresh)

    described_class.new.perform(user.id)

    expect(refresh).to have_received(:call!)
  end

  it "skips a deleted account" do
    user.soft_delete!
    allow(GithubInstallations::RefreshService).to receive(:new)

    described_class.new.perform(user.id)

    expect(GithubInstallations::RefreshService).not_to have_received(:new)
  end
end
