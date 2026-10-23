require "rails_helper"

RSpec.describe GithubRepos::DescribeService do
  let(:user) { create(:user, github_access_token: "gho_x") }
  let(:tokens) { GithubExtras::Tokens.new(user) }
  let!(:repo) { create(:github_repo, user: user, full_name: "me/app") }

  before { create(:entry, user: user, repo_name: "me/app") }

  it "keeps each repo's README line and custom picture, once a day" do
    allow(GithubGateway).to receive(:readme).and_return("# App\n\nA tool for builders.")
    allow(GithubGateway).to receive(:preview_image).and_return("https://repository-images.githubusercontent.com/1/x")

    expect(described_class.new(user: user, tokens: tokens).tap(&:call!).described).to eq(1)
    expect(repo.reload).to have_attributes(readme_line: "A tool for builders.", preview_image_url: "https://repository-images.githubusercontent.com/1/x")

    expect(described_class.new(user: user, tokens: tokens).tap(&:call!).described).to eq(0)
    expect(GithubGateway).to have_received(:readme).once
  end

  it "passes over excluded repos and repos with no work on Openstage" do
    create(:github_repo, user: user, full_name: "me/quiet")
    repo.update!(included: false)
    allow(GithubGateway).to receive(:readme)

    described_class.new(user: user, tokens: tokens).call!

    expect(GithubGateway).not_to have_received(:readme)
  end

  it "stops at a spent rate limit, leaving the repo for the next run" do
    allow(GithubGateway).to receive(:readme).and_raise(ApplicationGateway::RateLimited)

    expect(described_class.new(user: user, tokens: tokens).call).to be(true)
    expect(repo.reload.described_at).to be_nil
  end

  it "refuses without a builder or tokens" do
    expect(described_class.new(tokens: tokens).call).to be(false)
    expect(described_class.new(user: user).call).to be(false)
  end
end
