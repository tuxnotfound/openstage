require "rails_helper"

RSpec.describe GithubSyncJob, type: :job do
  let(:user) { create(:user, github_username: "tuxnotfound", github_access_token: "gho_token") }

  let(:repo_double) do
    double(
      id: 123_456,
      name: "myapp",
      full_name: "tuxnotfound/myapp",
      description: "My Rails app",
      html_url: "https://github.com/tuxnotfound/myapp",
      default_branch: "main"
    )
  end

  let(:commit_author_double) { double(login: "tuxnotfound") }
  let(:commit_git_author_double) { double(date: 1.day.ago) }
  let(:commit_commit_double) { double(message: "Add feature X\n\nMore details", author: commit_git_author_double) }

  let(:commit_double) do
    double(
      sha: "abc123def456",
      author: commit_author_double,
      commit: commit_commit_double,
      html_url: "https://github.com/tuxnotfound/myapp/commit/abc123def456"
    )
  end

  let(:client) { instance_double(Octokit::Client) }

  before do
    allow(Octokit::Client).to receive(:new).and_return(client)
    allow(client).to receive(:repos).and_return([ repo_double ])
    allow(client).to receive(:commits).and_return([ commit_double ])
  end

  describe "#perform" do
    it "creates a GithubRepo record" do
      expect { described_class.new.perform(user.id) }.to change(GithubRepo, :count).by(1)
    end

    it "creates an Entry for the commit" do
      expect { described_class.new.perform(user.id) }.to change(Entry, :count).by(1)
      entry = Entry.last
      expect(entry.entry_type).to eq("shipped")
      expect(entry.source).to eq("github")
      expect(entry.external_id).to eq("abc123def456")
      expect(entry.title).to eq("Add feature X")
    end

    it "creates a SyncLog with success status" do
      described_class.new.perform(user.id)
      log = SyncLog.last
      expect(log.status).to eq("success")
      expect(log.entries_added).to eq(1)
    end

    it "does not create duplicate entries on re-sync" do
      described_class.new.perform(user.id)
      expect { described_class.new.perform(user.id) }.not_to change(Entry, :count)
    end

    it "skips commits not authored by the user" do
      other_author = double(login: "someoneelse")
      allow(commit_double).to receive(:author).and_return(other_author)
      expect { described_class.new.perform(user.id) }.not_to change(Entry, :count)
    end

    context "when GitHub API raises an error" do
      before { allow(client).to receive(:repos).and_raise(Octokit::Unauthorized) }

      it "records a failed SyncLog and re-raises" do
        expect { described_class.new.perform(user.id) }.to raise_error(Octokit::Unauthorized)
        log = SyncLog.last
        expect(log.status).to eq("failed")
        expect(log.error_message).to be_present
      end
    end
  end
end
