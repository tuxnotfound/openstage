require "rails_helper"

# C12: private repos come from the Openstage GitHub App, read with an
# installation token; the sign-in token keeps listing the public ones.
RSpec.describe GithubSyncJob, "private repos through the GitHub App", type: :job do
  let(:user) do
    create(:user, github_username: "tuxnotfound", github_access_token: "gho_signin",
                  github_token_scopes: "user:email", github_installation_id: 7)
  end
  let(:public_repo) { repo(id: 1, name: "open", private: false) }
  let(:private_repo) { repo(id: 2, name: "secret", private: true) }
  let(:signin_client) { instance_double(Octokit::Client, scopes: [ "user:email" ]) }
  let(:app_client) { instance_double(Octokit::Client) }

  before do
    allow(Octokit::Client).to receive(:new).with(access_token: "gho_signin").and_return(signin_client)
    allow(Octokit::Client).to receive(:new).with(access_token: "ghs_installation").and_return(app_client)
    allow(GithubAppGateway).to receive(:installation_token).with(7).and_return("ghs_installation")
    allow(signin_client).to receive_messages(repositories: [ public_repo ], commits: [])
    allow(app_client).to receive_messages(list_app_installation_repositories: double(repositories: [ private_repo ]), commits: [])
    allow(signin_client).to receive(:access_token).and_return("gho_signin")
    allow(app_client).to receive(:access_token).and_return("ghs_installation")
    allow(GithubGateway).to receive(:branches).and_return([])
  end

  it "lists the picked private repos with the installation token, excluded by default" do
    described_class.new.perform(user.id)

    expect(user.github_repos.find_by(github_repo_id: 2)).to have_attributes(private_repo: true, included: false)
    expect(app_client).not_to have_received(:commits)
  end

  it "reads commits of an included private repo with the installation token, without links" do
    create(:github_repo, user: user, github_repo_id: 2, full_name: "tuxnotfound/secret",
                         private_repo: true, included: true, included_chosen: true)
    allow(app_client).to receive(:commits).and_return([ commit("abc") ])

    described_class.new.perform(user.id)

    expect(app_client).to have_received(:commits).with("tuxnotfound/secret", "main", hash_including(per_page: 100))
    expect(user.entries.find_by(external_id: "abc")).to have_attributes(repo_name: "tuxnotfound/secret", url: nil)
  end

  # The doubles only check what the job passes. This runs Octokit's real call
  # and pins the request GitHub receives, as the sign-in listing spec does.
  it "pages the installation listing through the real Octokit request" do
    allow(Octokit::Client).to receive(:new).with(access_token: "ghs_installation").and_call_original
    listing = stub_request(:get, "https://api.github.com/installation/repositories?page=1&per_page=100")
      .with { |request| request.headers["Authorization"].include?("ghs_installation") }
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: {
        total_count: 1,
        repositories: [ { id: 2, name: "secret", full_name: "tuxnotfound/secret", private: true,
                          default_branch: "main", html_url: "https://github.com/tuxnotfound/secret" } ]
      }.to_json)

    described_class.new.perform(user.id)

    expect(listing).to have_been_requested
    expect(user.github_repos.find_by(github_repo_id: 2)).to have_attributes(private_repo: true, included: false)
  end

  it "syncs a repo on both listings once" do
    allow(app_client).to receive(:list_app_installation_repositories).and_return(double(repositories: [ public_repo ]))

    described_class.new.perform(user.id)

    expect(signin_client).to have_received(:commits).once
    expect(app_client).not_to have_received(:commits)
  end

  # A 404 is an uninstall or a reinstall under a new id. Dropping on it would
  # lose every include of a reinstall, so this run drops nothing; the next
  # Settings check or webhook settles it.
  it "forgets an installation GitHub no longer has, drops nothing this run, and still syncs public repos" do
    create(:github_repo, user: user, github_repo_id: 2, full_name: "tuxnotfound/secret", private_repo: true, included: true)
    allow(GithubAppGateway).to receive(:installation_token).and_raise(ApplicationGateway::NotFound.new(status: 404))

    described_class.new.perform(user.id)

    expect(user.reload.github_installation_id).to be_nil
    expect(user.sync_logs.last).to have_attributes(status: "success")
    expect(user.github_repos.find_by(github_repo_id: 1)).to be_present
    expect(user.github_repos.find_by(github_repo_id: 2)).to be_present
  end

  it "keeps a newer installation id that a reinstall stored meanwhile" do
    allow(GithubAppGateway).to receive(:installation_token).with(7) do
      User.where(id: user.id).update_all(github_installation_id: 8)
      raise ApplicationGateway::NotFound.new(status: 404)
    end

    described_class.new.perform(user.id)

    expect(user.reload.github_installation_id).to eq(8)
  end

  # The review's high finding: signing up starts a sync that loads the user
  # before the App is connected. The Settings check then connects it and
  # records the private repos while the sync is still importing.
  it "never deletes private repos that a Settings check recorded while it ran" do
    user.update!(github_installation_id: nil)
    allow(GithubAppGateway).to receive(:installation_token).with(8).and_return("ghs_installation")
    allow(app_client).to receive(:list_app_installation_repositories).and_return(double(repositories: []))
    allow(signin_client).to receive(:repositories) do
      User.where(id: user.id).update_all(github_installation_id: 8)
      create(:github_repo, user: user, github_repo_id: 3, full_name: "tuxnotfound/connected", private_repo: true)
      [ public_repo ]
    end

    described_class.new.perform(user.id)

    expect(GithubAppGateway).to have_received(:installation_token).with(8)
    expect(user.github_repos.find_by(github_repo_id: 3)).to be_present
  end

  # GitHub answers 409 for a repo with no commits yet; that is not a failure.
  it "treats an empty repo as nothing to import, not as skipped" do
    create(:github_repo, user: user, github_repo_id: 2, full_name: "tuxnotfound/secret", private_repo: true,
                         included: true, included_chosen: true)
    allow(app_client).to receive(:commits).and_raise(Octokit::Conflict.new)

    described_class.new.perform(user.id)

    expect(user.sync_logs.last).to have_attributes(status: "success", error_message: nil)
    expect(user.github_repos.find_by(github_repo_id: 2).last_synced_at).to be_nil
  end

  # Pedro's test, 2026-10-09: codeconvert taken out of the App on GitHub still
  # sat in Settings, and including it there looked like it published something.
  it "removes a private repo taken out of the App, and brings it back excluded when picked again" do
    create(:github_repo, user: user, github_repo_id: 3, full_name: "tuxnotfound/dropped",
                         private_repo: true, included: true, included_chosen: true)
    entry = create(:entry, user: user, source: "github", repo_name: "tuxnotfound/dropped", hidden: false)

    described_class.new.perform(user.id)
    expect(user.github_repos.find_by(github_repo_id: 3)).to be_nil
    expect(entry.reload.hidden).to be(true)

    allow(app_client).to receive(:list_app_installation_repositories)
      .and_return(double(repositories: [ private_repo, repo(id: 3, name: "dropped", private: true) ]))
    described_class.new.perform(user.id)
    expect(user.github_repos.find_by(github_repo_id: 3)).to have_attributes(included: false)
    expect(entry.reload.hidden).to be(true)
  end

  it "never asks for an installation token without an installation" do
    user.update!(github_installation_id: nil)

    described_class.new.perform(user.id)

    expect(GithubAppGateway).not_to have_received(:installation_token)
  end

  def repo(id:, name:, private:)
    double(id: id, name: name, full_name: "tuxnotfound/#{name}", description: nil,
           html_url: "https://github.com/tuxnotfound/#{name}", default_branch: "main", private: private, stargazers_count: 0,
           homepage: nil, archived: false)
  end

  def commit(sha)
    double(sha: sha, author: double(login: "tuxnotfound"), html_url: "https://github.com/tuxnotfound/secret/commit/#{sha}",
           commit: double(message: "Ship it", author: double(date: 1.day.ago, email: "t@example.com")))
  end
end
