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

  it "forgets an installation GitHub no longer has, and still syncs public repos" do
    allow(GithubAppGateway).to receive(:installation_token).and_raise(ApplicationGateway::NotFound.new(status: 404))

    described_class.new.perform(user.id)

    expect(user.reload.github_installation_id).to be_nil
    expect(user.sync_logs.last).to have_attributes(status: "success")
    expect(user.github_repos.find_by(github_repo_id: 1)).to be_present
  end

  it "never asks for an installation token without an installation" do
    user.update!(github_installation_id: nil)

    described_class.new.perform(user.id)

    expect(GithubAppGateway).not_to have_received(:installation_token)
  end

  def repo(id:, name:, private:)
    double(id: id, name: name, full_name: "tuxnotfound/#{name}", description: nil,
           html_url: "https://github.com/tuxnotfound/#{name}", default_branch: "main", private: private)
  end

  def commit(sha)
    double(sha: sha, author: double(login: "tuxnotfound"), html_url: "https://github.com/tuxnotfound/secret/commit/#{sha}",
           commit: double(message: "Ship it", author: double(date: 1.day.ago, email: "t@example.com")))
  end
end
