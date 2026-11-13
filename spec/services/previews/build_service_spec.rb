require "rails_helper"
require "support/github_profile"

RSpec.describe Previews::BuildService do
  include GithubProfileData

  let(:today) { Date.new(2026, 11, 12) }

  it "builds the preview from the profile and the latest commits of the projects worked on last" do
    old = github_profile_repo(name: "old", days: { today - 200 => 9 })
    engine = github_profile_repo(name: "engine", days: { today - 2 => 4 })
    allow(GithubProfileGateway).to receive(:profile).with("ada", from: Preview.first_day(today), to: today).and_return(github_profile(repos: [ old, engine ]))
    allow(GithubProfileGateway).to receive(:commits).and_return([ github_profile_commit ])

    service = described_class.new(login: "ada", today: today)

    expect(service.call).to be(true)
    expect(service.preview.projects.map(&:name)).to eq(%w[old engine])
    expect(service.preview.latest.map(&:title)).to eq([ "Add the mill" ])
    expect(GithubProfileGateway).to have_received(:commits).with("U_ada", [ "ada/engine", "ada/old" ], per_repo: described_class::RECENT_PER_REPO)
  end

  it "reads the public repos instead of commits when the 12 months have none" do
    allow(GithubProfileGateway).to receive(:profile).and_return(github_profile(repos: []))
    allow(GithubProfileGateway).to receive(:commits)
    allow(GithubProfileGateway).to receive(:recent_repos).with("ada", count: described_class::QUIET_REPOS).and_return([ github_recent_repo ])

    service = described_class.new(login: "ada", today: today)

    expect(service.call).to be(true)
    expect(service.preview).to be_empty
    expect(service.preview.quiet_repos.map(&:name)).to eq(%w[notes])
    expect(GithubProfileGateway).not_to have_received(:commits)
  end

  it "reads no public repos for a preview with commits" do
    allow(GithubProfileGateway).to receive(:profile).and_return(github_profile(repos: [ github_profile_repo(days: { today - 2 => 4 }) ]))
    allow(GithubProfileGateway).to receive(:commits).and_return([])
    allow(GithubProfileGateway).to receive(:recent_repos)

    expect(described_class.new(login: "ada", today: today).tap(&:call).preview.quiet_repos).to eq([])
    expect(GithubProfileGateway).not_to have_received(:recent_repos)
  end

  it "refuses a login GitHub could never have, without asking it" do
    allow(GithubProfileGateway).to receive(:profile)

    service = described_class.new(login: "your_username", today: today)

    expect(service.call).to be(false)
    expect(service.errors.full_messages).to eq([ "Login is not a GitHub username" ])
    expect(GithubProfileGateway).not_to have_received(:profile)
  end

  it "says so when GitHub has no such user" do
    allow(GithubProfileGateway).to receive(:profile).and_raise(ApplicationGateway::NotFound.new(status: 404))

    service = described_class.new(login: "nobody", today: today)

    expect(service.call).to be(false)
    expect(service.errors.full_messages).to eq([ "Login is not on GitHub" ])
  end

  it "lets a GitHub failure raise" do
    allow(GithubProfileGateway).to receive(:profile).and_raise(ApplicationGateway::ServerError.new(status: 502))

    expect { described_class.new(login: "ada", today: today).call }.to raise_error(ApplicationGateway::ServerError)
  end
end
