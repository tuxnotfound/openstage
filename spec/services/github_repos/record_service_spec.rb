require "rails_helper"

# C10, amended 2026-09-11: private repos are excluded by DEFAULT (consent was
# never given), but a user who opts one in publishes its commit messages. Code
# private, build public. The product never overrides that choice.
RSpec.describe GithubRepos::RecordService do
  let(:user) { create(:user, github_username: "tuxnotfound") }

  def record(name:, private:, id: nil, branch: "main")
    listing = GithubAppGateway::Repo.new(
      id: id || name.hash.abs, name: name, full_name: "tuxnotfound/#{name}", description: "d",
      html_url: "https://github.com/tuxnotfound/#{name}", default_branch: branch, private: private
    )
    described_class.new(user: user, listing: listing).tap(&:call!).repo
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

  it "requires a user" do
    expect(described_class.new(user: nil, listing: double).call).to be(false)
  end

  it "requires a listing" do
    service = described_class.new(user: user, listing: nil)
    expect(service.call).to be(false)
    expect(service.errors[:listing]).to be_present
  end
end
