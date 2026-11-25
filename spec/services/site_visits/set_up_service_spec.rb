require "rails_helper"

RSpec.describe SiteVisits::SetUpService do
  let(:user) { create(:user, pro: true) }
  let(:repo) { create(:github_repo, user: user, name: "shipnote", homepage: "https://shipnote.app") }

  it "picks the script, and leaves a website the app already reads as GitHub's" do
    described_class.new(repo: repo, website: "https://shipnote.app").call!

    expect(repo.reload).to have_attributes(site_source: "script", website_edit: nil)
    expect(repo.site_token).to start_with("os_")
  end

  it "keeps another website as the builder's own" do
    described_class.new(repo: repo, website: "https://shipnote.io").call!

    expect(repo.reload).to have_attributes(website_edit: "https://shipnote.io", site_host: "shipnote.io")
  end

  it "keeps nothing when the script is refused" do
    create(:github_repo, user: user, site_set_up_at: 1.day.ago, homepage: "https://first.dev")
    user.update!(pro: false)
    service = described_class.new(repo: repo, website: "https://shipnote.io")

    expect(service.call).to be(false)
    expect(service.errors.full_messages).to eq([ "Free counts site visits for one project, #{user.github_repos.first.name}. Go Pro to count them for every project." ])
    expect(repo.reload).to have_attributes(website_edit: nil, site_source: nil)
  end

  it "refuses a website that is not one, before anything else" do
    service = described_class.new(repo: repo, website: "shipnote.io")

    expect(service.call).to be(false)
    expect(service.errors.full_messages).to eq([ "Website edit must start with http:// or https://" ])
    expect(repo.reload.site_source).to be_nil
  end

  it "needs a project" do
    expect(described_class.new(website: "https://shipnote.app").call).to be(false)
  end
end
