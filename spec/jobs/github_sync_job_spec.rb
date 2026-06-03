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
      default_branch: "main",
      private: false
    )
  end

  let(:commit_author_double) { double(login: "tuxnotfound") }
  let(:commit_git_author_double) { double(date: 1.day.ago, email: "tuxnotfound@example.com") }
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
    allow(client).to receive(:repositories).and_return([ repo_double ])
    allow(client).to receive(:commits).and_return([ commit_double ])
    # Single-page stub: no :next rel means each_page yields once and stops.
    allow(client).to receive(:last_response).and_return(double(rels: {}))
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
      expect(entry.url).to eq("https://github.com/tuxnotfound/myapp/commit/abc123def456")
    end

    it "does not store commit URL for private repos" do
      allow(repo_double).to receive(:private).and_return(true)

      described_class.new.perform(user.id)
      expect(Entry.last.url).to be_nil
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
      allow(commit_git_author_double).to receive(:email).and_return("someoneelse@example.com")
      expect { described_class.new.perform(user.id) }.not_to change(Entry, :count)
    end

    it "includes commits when author is nil but committer uses the GitHub noreply email" do
      allow(commit_double).to receive(:author).and_return(nil)
      allow(commit_git_author_double).to receive(:email).and_return("12345+TuxNotFound@users.noreply.github.com")
      expect { described_class.new.perform(user.id) }.to change(Entry, :count).by(1)
    end

    it "rescans from INITIAL_SYNC_WINDOW when the repo's default branch changes" do
      described_class.new.perform(user.id)
      initial_synced = GithubRepo.last.last_synced_at

      allow(repo_double).to receive(:default_branch).and_return("trunk")

      captured_since = nil
      allow(client).to receive(:commits) do |_full_name, _branch, opts|
        captured_since = Time.parse(opts[:since])
        []
      end

      travel_to(2.hours.from_now) { described_class.new.perform(user.id) }

      # Without the reset, since would be ~initial_synced - SINCE_OVERLAP.
      # With the reset, since is ~INITIAL_SYNC_WINDOW.ago — far older.
      expect(captured_since).to be < (initial_synced - 1.week)
    end

    it "does not reset last_synced_at when the default branch is unchanged" do
      described_class.new.perform(user.id)
      initial_synced = GithubRepo.last.last_synced_at

      captured_since = nil
      allow(client).to receive(:commits) do |_full_name, _branch, opts|
        captured_since = Time.parse(opts[:since])
        []
      end

      travel_to(2.hours.from_now) { described_class.new.perform(user.id) }

      # Normal sync: since is last_synced_at - 1.day, not the wide window.
      expect(captured_since).to be_within(2.seconds).of(initial_synced - 1.day)
    end

    it "does not advance last_synced_at when a repo's commits endpoint errors" do
      described_class.new.perform(user.id)
      first_synced_at = GithubRepo.last.last_synced_at

      allow(client).to receive(:commits).and_raise(Octokit::ServerError.new)

      expect {
        travel_to(2.hours.from_now) { described_class.new.perform(user.id) }
      }.not_to(change { GithubRepo.last.reload.last_synced_at })

      expect(GithubRepo.last.last_synced_at).to be_within(1.second).of(first_synced_at)
    end

    context "when GitHub API raises an error" do
      before { allow(client).to receive(:repositories).and_raise(Octokit::Unauthorized) }

      it "records a failed SyncLog and re-raises" do
        expect { described_class.new.perform(user.id) }.to raise_error(Octokit::Unauthorized)
        log = SyncLog.last
        expect(log.status).to eq("failed")
        expect(log.error_message).to be_present
      end
    end
  end
end
