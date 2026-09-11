require "rails_helper"

# C10, amended 2026-09-11: private repos are excluded by DEFAULT (consent was
# never given), but a user who opts one in publishes its commit messages. Code
# private, build public. The product never overrides that choice.
RSpec.describe GithubSyncJob, "private repository handling", type: :job do
  let(:user) { create(:user, github_username: "tuxnotfound") }

  describe "consent defaults" do
    it "excludes a newly discovered private repo and includes a public one" do
      job = described_class.new

      secret = job.send(:sync_repo, user, repo_data(name: "secret", private: true))
      open   = job.send(:sync_repo, user, repo_data(name: "open", private: false))

      expect(secret).to have_attributes(private_repo: true, included: false)
      expect(open).to have_attributes(private_repo: false, included: true)
    end

    it "re-defaults to excluded the first time a repo is learned to be private" do
      legacy = create(:github_repo, user: user, github_repo_id: 42, name: "secret",
                                    full_name: "tuxnotfound/secret", included: true, private_repo: false)

      described_class.new.send(:sync_repo, user, repo_data(name: "secret", private: true, id: 42))

      expect(legacy.reload).to have_attributes(private_repo: true, included: false)
    end

    it "respects a deliberate opt-in on every later sync" do
      job = described_class.new
      repo = job.send(:sync_repo, user, repo_data(name: "secret", private: true, id: 7))
      repo.update!(included: true)

      job.send(:sync_repo, user, repo_data(name: "secret", private: true, id: 7))
      expect(repo.reload.included?).to be(true)
    end
  end

  describe "entries from an opted-in private repo" do
    it "are public, because publishing them is the whole point of opting in" do
      repo = create(:github_repo, user: user, full_name: "tuxnotfound/secret",
                                  private_repo: true, included: true)
      entry = create(:entry, user: user, source: "github", repo_name: repo.full_name)

      described_class.new.send(:hide_excluded_private_entries, user)

      expect(entry.reload).to have_attributes(hidden: false, visibility: "public_entry")
      expect(user.entries.publicly_visible).to include(entry)
    end
  end

  describe "entries from a private repo nobody opted into" do
    it "are hidden and stripped of commit links" do
      create(:github_repo, user: user, full_name: "tuxnotfound/secret",
                           private_repo: true, included: false)
      leaked = create(:entry, user: user, source: "github", repo_name: "tuxnotfound/secret",
                              hidden: false, url: "https://github.com/tuxnotfound/secret/commit/abc")

      described_class.new.send(:hide_excluded_private_entries, user)

      expect(leaked.reload).to have_attributes(hidden: true, url: nil)
      expect(user.entries.publicly_visible).not_to include(leaked)
    end

    it "still works after the repo scope is revoked and GitHub stops listing it" do
      # No repo_data at all: the sweep reads our own table, not the API.
      create(:github_repo, user: user, full_name: "tuxnotfound/vanished",
                           private_repo: true, included: false)
      orphan = create(:entry, user: user, source: "github", repo_name: "tuxnotfound/vanished", hidden: false)

      described_class.new.send(:hide_excluded_private_entries, user)
      expect(orphan.reload.hidden).to be(true)
    end

    it "leaves public-repo entries alone" do
      create(:github_repo, user: user, full_name: "tuxnotfound/open", private_repo: false)
      safe = create(:entry, user: user, source: "github", repo_name: "tuxnotfound/open", hidden: false)

      described_class.new.send(:hide_excluded_private_entries, user)
      expect(safe.reload.hidden).to be(false)
    end
  end

  describe "the public repo count" do
    it "counts only public repos, so a private one is not disclosed by the stat" do
      create(:github_repo, user: user, included: true, private_repo: false)
      create(:github_repo, user: user, included: true, private_repo: true)

      expect(user.github_repos.included_repos.public_repos.count).to eq(1)
    end
  end

  RepoData = Struct.new(:id, :name, :full_name, :description, :html_url, :default_branch, :private,
                        keyword_init: true)

  def repo_data(name:, private:, id: nil)
    RepoData.new(
      id: id || name.hash.abs, name: name, full_name: "tuxnotfound/#{name}",
      description: "d", html_url: "https://github.com/tuxnotfound/#{name}",
      default_branch: "main", private: private
    )
  end
end
