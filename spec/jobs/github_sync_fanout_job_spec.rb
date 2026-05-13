require "rails_helper"

RSpec.describe GithubSyncFanoutJob, type: :job do
  describe "#perform" do
    it "enqueues a GithubSyncJob for each active user with a token" do
      active = create(:user, github_username: "alice", github_access_token: "gho_a")
      create(:user, github_username: "bob", github_access_token: "gho_b").soft_delete!
      create(:user, github_username: "carol", github_access_token: nil)

      expect(GithubSyncJob).to receive(:perform_later).with(active.id).once

      described_class.new.perform
    end
  end
end
