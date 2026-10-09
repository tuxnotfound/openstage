require "rails_helper"

# C12, after Pedro's test on 2026-10-09: GitHub did not send him back after
# installing or after changing repos, so Openstage never heard of either.
# The refresh asks GitHub instead of waiting to be told.
RSpec.describe GithubInstallations::RefreshService do
  let(:user) { create(:user, github_uid: "123", github_username: "tuxnotfound", github_token_scopes: "user:email") }
  let(:not_found) { ApplicationGateway::NotFound.new(status: 404) }

  def listing(id, name, private: true)
    GithubAppGateway::Repo.new(id: id, name: name, full_name: "tuxnotfound/#{name}", description: nil,
                               html_url: "https://github.com/tuxnotfound/#{name}", default_branch: "main", private: private)
  end

  def refresh
    described_class.new(user: user).tap(&:call!)
  end

  before do
    allow(GithubAppGateway).to receive(:user_installation).and_raise(not_found)
    allow(GithubAppGateway).to receive(:installation_repositories).and_raise(not_found)
    allow(GithubAppGateway).to receive(:repository).and_raise(not_found)
  end

  it "connects an installation GitHub never sent the builder back from, with its repos excluded" do
    allow(GithubAppGateway).to receive(:user_installation).with("tuxnotfound").and_return(id: 7, account_id: 123)
    allow(GithubAppGateway).to receive(:installation_repositories).with(7).and_return([ listing(1, "secret") ])

    refresh

    expect(user.reload.github_installation_id).to eq(7)
    expect(user.github_repos.find_by(github_repo_id: 1)).to have_attributes(private_repo: true, included: false)
  end

  it "reads the known installation without looking it up again" do
    user.update!(github_installation_id: 7)
    allow(GithubAppGateway).to receive(:installation_repositories).with(7).and_return([ listing(1, "secret") ])

    refresh

    expect(GithubAppGateway).not_to have_received(:user_installation)
    expect(user.github_repos.pluck(:github_repo_id)).to eq([ 1 ])
  end

  it "drops a repo taken out of the App and hides its commits" do
    user.update!(github_installation_id: 7)
    create(:github_repo, user: user, github_repo_id: 2, full_name: "tuxnotfound/dropped", private_repo: true, included: true)
    entry = create(:entry, user: user, source: "github", repo_name: "tuxnotfound/dropped", hidden: false)
    allow(GithubAppGateway).to receive(:installation_repositories).with(7).and_return([ listing(1, "secret") ])

    refresh

    expect(user.github_repos.find_by(github_repo_id: 2)).to be_nil
    expect(entry.reload.hidden).to be(true)
  end

  it "forgets an uninstalled App and drops its private repos, never a public one" do
    user.update!(github_installation_id: 7)
    create(:github_repo, user: user, github_repo_id: 2, private_repo: true)
    create(:github_repo, user: user, github_repo_id: 3, private_repo: false)

    refresh

    expect(user.reload.github_installation_id).to be_nil
    expect(user.github_repos.pluck(:github_repo_id)).to eq([ 3 ])
  end

  # Uninstalling and installing again gives a new installation id.
  it "follows a reinstall to its new installation" do
    user.update!(github_installation_id: 7)
    allow(GithubAppGateway).to receive(:user_installation).with("tuxnotfound").and_return(id: 8, account_id: 123)
    allow(GithubAppGateway).to receive(:installation_repositories).with(8).and_return([ listing(1, "secret") ])

    refresh

    expect(user.reload.github_installation_id).to eq(8)
    expect(user.github_repos.pluck(:github_repo_id)).to eq([ 1 ])
  end

  # github_username is refreshed only at sign-in; a renamed builder's old name
  # may belong to someone else now.
  it "never connects an installation on another account, says why, and drops nothing" do
    create(:github_repo, user: user, github_repo_id: 2, private_repo: true)
    allow(GithubAppGateway).to receive(:user_installation).and_return(id: 9, account_id: 555)
    service = described_class.new(user: user)

    expect(service.call).to be(false)
    expect(service.errors.full_messages).to include(described_class::RENAMED)
    expect(user.reload.github_installation_id).to be_nil
    expect(user.github_repos.find_by(github_repo_id: 2)).to be_present
    expect(GithubAppGateway).not_to have_received(:installation_repositories)
  end

  # Taken out of the App after going public: dropping it would hide its commits
  # and erase their links, and the next sync would bring it back as new.
  it "records a repo that went public instead of dropping it" do
    user.update!(github_installation_id: 7)
    create(:github_repo, user: user, github_repo_id: 2, full_name: "tuxnotfound/tool", private_repo: true, included: true)
    entry = create(:entry, user: user, source: "github", repo_name: "tuxnotfound/tool", hidden: false)
    allow(GithubAppGateway).to receive(:installation_repositories).with(7).and_return([])
    allow(GithubAppGateway).to receive(:repository).with(2, token: user.github_access_token)
                                                   .and_return(listing(2, "tool", private: false))

    refresh

    expect(user.github_repos.find_by(github_repo_id: 2)).to have_attributes(private_repo: false, included: true)
    expect(entry.reload.hidden).to be(false)
  end

  # A webhook and a Settings check can both see the stale id after a reinstall;
  # the one that loses must neither wipe the new id the other stored nor, unable
  # to look it up itself, drop the repos that id still reads.
  it "keeps and reads a newer installation id stored meanwhile" do
    user.update!(github_installation_id: 7)
    create(:github_repo, user: user, github_repo_id: 1, full_name: "tuxnotfound/secret", private_repo: true, included: true)
    User.where(id: user.id).update_all(github_installation_id: 8)
    allow(GithubAppGateway).to receive(:installation_repositories).with(8).and_return([ listing(1, "secret") ])

    refresh

    expect(user.reload.github_installation_id).to eq(8)
    expect(user.github_repos.find_by(github_repo_id: 1)).to have_attributes(included: true)
  end

  it "leaves private repos alone for a builder still on the repo-scoped token" do
    user.update!(github_token_scopes: "repo,user:email")
    create(:github_repo, user: user, github_repo_id: 2, private_repo: true, included: true)

    refresh

    expect(user.github_repos.find_by(github_repo_id: 2)).to be_present
  end

  it "requires a user" do
    expect(described_class.new(user: nil).call).to be(false)
  end
end
