require "rails_helper"

# C10: a public proof-of-work page must never publish private-repo work.
RSpec.describe GithubSyncJob, "private repository handling", type: :job do
  let(:user) { create(:user, github_username: "tuxnotfound") }

  describe "new repositories" do
    it "excludes a private repo by default and includes a public one" do
      job = described_class.new

      private_repo = job.send(:sync_repo, user, repo_data(name: "secret", private: true))
      public_repo  = job.send(:sync_repo, user, repo_data(name: "open", private: false))

      expect(private_repo.private_repo?).to be(true)
      expect(private_repo.included?).to be(false)
      expect(public_repo.included?).to be(true)
    end

    it "remembers an explicit opt-in on later syncs" do
      job = described_class.new
      repo = job.send(:sync_repo, user, repo_data(name: "secret", private: true))
      repo.update!(included: true)

      job.send(:sync_repo, user, repo_data(name: "secret", private: true))
      expect(repo.reload.included?).to be(true)
    end
  end

  describe "leaked entries" do
    it "privatises public entries that came from a private repo, and drops their URLs" do
      repo = create(:github_repo, user: user, full_name: "tuxnotfound/secret", private_repo: true)
      leaked = create(:entry, user: user, source: "github", repo_name: "tuxnotfound/secret",
                              visibility: "public", url: "https://github.com/tuxnotfound/secret/commit/abc")

      described_class.new.send(:privatize_existing_entries, user, repo)

      leaked.reload
      expect(leaked.visibility).to eq("private_entry")
      expect(leaked.url).to be_nil
    end

    it "leaves public-repo entries alone" do
      repo = create(:github_repo, user: user, full_name: "tuxnotfound/open", private_repo: false)
      safe = create(:entry, user: user, source: "github", repo_name: "tuxnotfound/open", visibility: "public")

      described_class.new.send(:privatize_existing_entries, user, repo)
      expect(safe.reload.visibility).to eq("public_entry")
    end
  end

  describe "the public profile" do
    it "counts only public repos, so private ones are not disclosed by the stat" do
      create(:github_repo, user: user, included: true, private_repo: false)
      create(:github_repo, user: user, included: true, private_repo: true)

      expect(user.github_repos.included_repos.public_repos.count).to eq(1)
    end
  end

  # Stands in for the Sawyer::Resource the GitHub API returns.
  RepoData = Struct.new(:id, :name, :full_name, :description, :html_url, :default_branch, :private,
                        keyword_init: true)

  def repo_data(name:, private:)
    RepoData.new(
      id: name.hash.abs, name: name, full_name: "tuxnotfound/#{name}",
      description: "d", html_url: "https://github.com/tuxnotfound/#{name}",
      default_branch: "main", private: private
    )
  end
end
