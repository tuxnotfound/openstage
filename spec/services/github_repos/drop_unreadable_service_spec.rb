require "rails_helper"

RSpec.describe GithubRepos::DropUnreadableService do
  let(:user) { create(:user) }
  let!(:readable) { create(:github_repo, user: user, github_repo_id: 1, full_name: "me/readable", private_repo: true, included: true) }
  let!(:gone) { create(:github_repo, user: user, github_repo_id: 2, full_name: "me/gone", private_repo: true, included: true) }
  let!(:public_repo) { create(:github_repo, user: user, github_repo_id: 3, full_name: "me/open", private_repo: false) }

  it "drops the private repos not listed and hides their commits" do
    gone_entry = create(:entry, user: user, source: "github", repo_name: "me/gone", hidden: false,
                                url: "https://github.com/me/gone/commit/abc")
    kept_entry = create(:entry, user: user, source: "github", repo_name: "me/readable", hidden: false)
    service = described_class.new(user: user, listed_ids: [ 1 ], listed_at: Time.current)

    expect(service.call).to be(true)
    expect(service.dropped).to eq([ "me/gone" ])
    expect(user.github_repos.pluck(:github_repo_id)).to contain_exactly(1, 3)
    expect(gone_entry.reload).to have_attributes(hidden: true, url: nil)
    expect(kept_entry.reload.hidden).to be(false)
  end

  it "drops every private repo when nothing is readable, and never a public one" do
    described_class.new(user: user, listed_ids: [], listed_at: Time.current).call!

    expect(user.github_repos.pluck(:github_repo_id)).to eq([ 3 ])
  end

  # A Settings check or webhook can record a repo while a long sync runs. That
  # sync's listing predates the row, so its absence there means nothing.
  it "never drops a row recorded after the listing began" do
    listed_at = 1.minute.ago

    described_class.new(user: user, listed_ids: [], listed_at: listed_at).call!

    expect(user.github_repos.pluck(:github_repo_id)).to contain_exactly(1, 2, 3)
  end

  it "requires the listing time" do
    expect(described_class.new(user: user, listed_ids: [], listed_at: nil).call).to be(false)
    expect(user.github_repos.count).to eq(3)
  end

  it "requires a user" do
    expect(described_class.new(user: nil, listed_ids: [], listed_at: Time.current).call).to be(false)
  end

  # A missing list must not read as "nothing is readable".
  it "requires the listed ids" do
    expect(described_class.new(user: user, listed_ids: nil, listed_at: Time.current).call).to be(false)
    expect(user.github_repos.count).to eq(3)
  end
end
