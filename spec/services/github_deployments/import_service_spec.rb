require "rails_helper"

RSpec.describe GithubDeployments::ImportService do
  let(:user) { create(:user, github_username: "tux") }
  let(:json) { { "Content-Type" => "application/json" } }
  let!(:repo) { create(:github_repo, user: user, name: "app", full_name: "tux/app") }

  before do
    create(:entry, user: user, source: "github", entry_type: "shipped", repo_name: "tux/app", occurred_at: 2.days.ago)
  end

  def deployment(id, environment: "production", created_at: 1.day.ago)
    { id: id, environment: environment, created_at: created_at&.iso8601, creator: { login: "github-actions[bot]" } }
  end

  def deployments_url(full_name = "tux/app")
    "https://api.github.com/repos/#{full_name}/deployments?per_page=50"
  end

  def stub_deployments(*deployments, full_name: "tux/app")
    stub_request(:get, deployments_url(full_name)).to_return(status: 200, headers: json, body: deployments.to_json)
  end

  def import
    described_class.new(user: user, tokens: GithubExtras::Tokens.new(user)).tap(&:call!)
  end

  it "keeps the repo's deploys whoever made them, once" do
    stub_deployments(deployment(1), deployment(2, environment: "Production – app"))

    expect(import.imported).to eq(2)
    expect(import.imported).to eq(0)
    expect(GithubActivity.where(user: user).pluck(:kind, :external_id, :environment, :github_repo_id)).to contain_exactly(
      [ "deployment", 1, "production", repo.id ], [ "deployment", 2, "Production – app", repo.id ]
    )
  end

  it "leaves out previews, staging and other trial environments" do
    trials = [ "Preview", "staging", "review-app", "develop", "Development", "dev", "test", "Testing", "QA", "pr-123", "app-pr-12",
               "Preview – app" ]
    stub_deployments(*trials.each_with_index.map { |environment, i| deployment(i + 10, environment: environment) },
                     deployment(1, environment: "github-pages"), deployment(2, environment: "devops-production"))

    expect(import.imported).to eq(2)
    expect(GithubActivity.pluck(:environment)).to contain_exactly("github-pages", "devops-production")
  end

  it "leaves out deploys from before the window" do
    stub_deployments(deployment(1, created_at: 9.weeks.ago), deployment(2))

    expect(import.imported).to eq(1)
  end

  it "asks only about included repos with recent commits" do
    quiet = create(:github_repo, user: user, full_name: "tux/quiet")
    create(:entry, user: user, source: "github", entry_type: "shipped", repo_name: quiet.full_name, occurred_at: 3.months.ago)
    excluded = create(:github_repo, user: user, full_name: "tux/hidden", included: false)
    create(:entry, user: user, source: "github", entry_type: "shipped", repo_name: excluded.full_name, occurred_at: 2.days.ago)
    stub_deployments

    import
    expect(a_request(:get, %r{/repos/tux/(quiet|hidden)/deployments})).not_to have_been_made
  end

  context "with a second active repo" do
    before do
      create(:github_repo, user: user, name: "site", full_name: "tux/site")
      create(:entry, user: user, source: "github", entry_type: "shipped", repo_name: "tux/site", occurred_at: 1.day.ago)
    end

    it "skips a repo the token cannot read and carries on" do
      stub_request(:get, deployments_url).to_return(status: 403, headers: json, body: "{}")
      stub_deployments(deployment(1), full_name: "tux/site")

      expect(import.imported).to eq(1)
    end

    it "stops at the rate limit" do
      limited = { status: 403, headers: json.merge("X-RateLimit-Remaining" => "0"), body: "{}" }
      stub_request(:get, deployments_url).to_return(limited)
      stub_request(:get, deployments_url("tux/site")).to_return(limited)

      expect(import.imported).to eq(0)
      expect(a_request(:get, %r{/repos/tux/(app|site)/deployments})).to have_been_made.once
    end
  end
end
