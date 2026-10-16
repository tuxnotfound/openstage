require "rails_helper"

RSpec.describe GithubReleases::ImportService do
  let(:user) { create(:user, github_username: "tux") }
  let(:json) { { "Content-Type" => "application/json" } }
  let!(:repo) { create(:github_repo, user: user, name: "app", full_name: "tux/app") }

  before do
    create(:entry, user: user, source: "github", entry_type: "shipped", repo_name: "tux/app", occurred_at: 2.days.ago)
  end

  def release(id, name: "", tag: "v1.#{id}", author: "tux", published_at: 1.day.ago, draft: false)
    { id: id, name: name, tag_name: tag, html_url: "https://github.com/tux/app/releases/#{tag}", draft: draft,
      published_at: published_at&.iso8601, author: { login: author } }
  end

  def stub_releases(*releases, full_name: "tux/app")
    stub_request(:get, "https://api.github.com/repos/#{full_name}/releases?per_page=30").to_return(status: 200, headers: json, body: releases.to_json)
  end

  def import
    described_class.new(user: user, tokens: GithubExtras::Tokens.new(user)).tap(&:call!)
  end

  it "adds the builder's releases as released entries, once" do
    stub_releases(release(1), release(2, name: "Arcade mode"))

    expect(import.imported).to eq(2)
    expect(import.imported).to eq(0)
    expect(user.entries.where(entry_type: "released").pluck(:title, :url, :repo_name)).to contain_exactly(
      [ "app v1.1", "https://github.com/tux/app/releases/v1.1", "tux/app" ],
      [ "Arcade mode", "https://github.com/tux/app/releases/v1.2", "tux/app" ]
    )
  end

  it "leaves out drafts, old releases, and someone else's release on a repo the builder does not own" do
    shared = create(:github_repo, user: user, name: "team", full_name: "acme/team")
    create(:entry, user: user, source: "github", entry_type: "shipped", repo_name: "acme/team", occurred_at: 2.days.ago)
    stub_releases(release(1, draft: true), release(2, published_at: 2.years.ago), release(3, published_at: nil))
    stub_releases(release(4, author: "teammate"), release(5), full_name: shared.full_name)

    expect(import.imported).to eq(1)
    expect(user.entries.find_by(external_id: "release-5")).to be_present
  end

  it "keeps a bot's release on the builder's own repo" do
    stub_releases(release(1, author: "github-actions[bot]"))

    expect(import.imported).to eq(1)
  end

  it "never brings back a release the builder deleted" do
    DismissedCommit.create!(user: user, sha: "release-1")
    stub_releases(release(1))

    expect(import.imported).to eq(0)
  end

  it "never links a private repo's release" do
    repo.update!(private_repo: true)
    stub_releases(release(1))

    import
    expect(user.entries.find_by(external_id: "release-1").url).to be_nil
  end

  it "asks only about included repos with recent commits" do
    quiet = create(:github_repo, user: user, full_name: "tux/quiet")
    create(:entry, user: user, source: "github", entry_type: "shipped", repo_name: quiet.full_name, occurred_at: 3.months.ago)
    stub_releases

    import
    expect(a_request(:get, %r{/repos/tux/quiet/releases})).not_to have_been_made
  end

  it "skips a repo GitHub no longer has" do
    stub_request(:get, "https://api.github.com/repos/tux/app/releases?per_page=30").to_return(status: 404, headers: json, body: "{}")

    expect(import.imported).to eq(0)
  end
end
