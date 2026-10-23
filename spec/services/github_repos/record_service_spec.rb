require "rails_helper"

# C10, amended 2026-09-11: private repos are excluded by DEFAULT (consent was
# never given), but a user who opts one in publishes its commit messages. Code
# private, build public. The product never overrides that choice.
RSpec.describe GithubRepos::RecordService do
  let(:user) { create(:user, github_username: "tuxnotfound") }

  def listing(name:, private:, id: nil, branch: "main")
    GithubAppGateway::Repo.new(
      id: id || name.hash.abs, name: name, full_name: "tuxnotfound/#{name}", description: "d",
      html_url: "https://github.com/tuxnotfound/#{name}", default_branch: branch, private: private
    )
  end

  def record(**attributes)
    described_class.new(user: user, listing: listing(**attributes)).tap(&:call!).repo
  end

  it "keeps the star count when the listing has one" do
    starred = GithubAppGateway::Repo.new(id: 77, name: "app", full_name: "tuxnotfound/app", description: nil,
                                         html_url: "https://github.com/tuxnotfound/app", default_branch: "main", private: false,
                                         stargazers_count: 12)

    expect(described_class.new(user: user, listing: starred).tap(&:call!).repo.stars_count).to eq(12)
    expect(record(name: "app", private: false, id: 77).stars_count).to eq(12)
  end

  it "keeps the repo's website and archive flag, as GitHub lists them" do
    live = GithubAppGateway::Repo.new(id: 78, name: "site", full_name: "tuxnotfound/site", description: nil,
                                      html_url: "https://github.com/tuxnotfound/site", default_branch: "main", private: false,
                                      homepage: "https://site.example", archived: true)

    expect(described_class.new(user: user, listing: live).tap(&:call!).repo)
      .to have_attributes(homepage: "https://site.example", archived: true)
    expect(record(name: "plain", private: false)).to have_attributes(homepage: nil, archived: false)
  end

  it "excludes a newly discovered private repo and includes a public one" do
    expect(record(name: "secret", private: true)).to have_attributes(private_repo: true, included: false)
    expect(record(name: "open", private: false)).to have_attributes(private_repo: false, included: true)
  end

  it "re-defaults to excluded the first time a repo is learned to be private" do
    legacy = create(:github_repo, user: user, github_repo_id: 42, name: "secret",
                                  full_name: "tuxnotfound/secret", included: true, private_repo: false)

    record(name: "secret", private: true, id: 42)

    expect(legacy.reload).to have_attributes(private_repo: true, included: false)
  end

  # The row can still read private_repo: false when the user includes it
  # (nothing listed it since the column shipped). Learning it is private
  # afterwards must not undo that click.
  it "never overrides an Included the user set by hand" do
    chosen = create(:github_repo, user: user, github_repo_id: 43, name: "secret",
                                  full_name: "tuxnotfound/secret", included: true, included_chosen: true, private_repo: false)

    record(name: "secret", private: true, id: 43)

    expect(chosen.reload).to have_attributes(private_repo: true, included: true)
  end

  it "respects a deliberate opt-in on every later sync" do
    repo = record(name: "secret", private: true, id: 7)
    repo.update!(included: true)

    record(name: "secret", private: true, id: 7)
    expect(repo.reload.included?).to be(true)
  end

  it "resets the sync watermark when the default branch is renamed" do
    repo = record(name: "open", private: false, id: 9)
    repo.update!(last_synced_at: 1.day.ago)

    record(name: "open", private: false, id: 9, branch: "trunk")
    expect(repo.reload).to have_attributes(default_branch: "trunk", last_synced_at: nil)
  end

  # Commits are tied to their repo by name, so a rename must carry them, or a
  # later exclude or drop would miss the ones from before it.
  it "carries the repo's commits through a rename" do
    repo = record(name: "stealth", private: true, id: 5)
    old = create(:entry, user: user, source: "github", repo_name: "tuxnotfound/stealth")
    note = create(:entry, user: user, source: "manual", repo_name: "tuxnotfound/stealth")

    record(name: "launch", private: true, id: 5)

    expect(repo.reload.full_name).to eq("tuxnotfound/launch")
    expect(old.reload.repo_name).to eq("tuxnotfound/launch")
    expect(note.reload.repo_name).to eq("tuxnotfound/stealth")
  end

  it "takes the commits of a repo just excluded for going private off the profile now" do
    public_repo = record(name: "app", private: false, id: 6)
    shown = create(:entry, user: user, source: "github", repo_name: public_repo.full_name, hidden: false,
                           url: "https://github.com/tuxnotfound/app/commit/abc")

    record(name: "app", private: true, id: 6)

    expect(public_repo.reload.included).to be(false)
    expect(shown.reload).to have_attributes(hidden: true, url: nil)
  end

  # Two recorders seeing the same new repo at once: the sync and a Settings
  # check, or the webhook and the Setup URL callback.
  describe "a repo recorded meanwhile by another writer" do
    let!(:theirs) do
      create(:github_repo, user: user, github_repo_id: 8, name: "race", full_name: "tuxnotfound/race", private_repo: true, included: false)
    end

    it "uses that row when the uniqueness check sees it first" do
      allow(GithubRepo).to receive(:find_or_initialize_by).and_return(GithubRepo.new(user: user, github_repo_id: 8))
      service = described_class.new(user: user, listing: listing(name: "race", private: true, id: 8))

      expect(service.call).to be(true)
      expect(service.repo).to eq(theirs)
    end

    it "uses that row when the insert loses on the unique index" do
      fresh = GithubRepo.new(user: user, github_repo_id: 8)
      allow(GithubRepo).to receive(:find_or_initialize_by).and_return(fresh)
      allow(fresh).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)
      service = described_class.new(user: user, listing: listing(name: "race", private: true, id: 8))

      expect(service.call).to be(true)
      expect(service.repo).to eq(theirs)
    end
  end

  it "requires a user" do
    expect(described_class.new(user: nil, listing: double).call).to be(false)
  end

  it "requires a listing" do
    service = described_class.new(user: user, listing: nil)
    expect(service.call).to be(false)
    expect(service.errors[:listing]).to be_present
  end
end
