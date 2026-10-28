require "rails_helper"

RSpec.describe SiteVisits::ConfigureService do
  let(:user) { create(:user, pro: true) }
  let(:repo) { create(:github_repo, user: user, homepage: "https://shipnote.app") }

  it "sets up the script with a token that stays when it is turned off and on" do
    described_class.new(repo: repo, source: "script").call!
    token = repo.reload.site_token

    described_class.new(repo: repo, source: "off").call!
    described_class.new(repo: repo, source: "script").call!

    expect(repo.reload).to have_attributes(site_source: "script", site_token: token)
  end

  it "needs a project" do
    expect(described_class.new(source: "script").call).to be(false)
  end

  it "refuses a source it does not know" do
    service = described_class.new(repo: repo, source: "vercel")

    expect(service.call).to be(false)
    expect(service.errors[:source]).to be_present
  end

  it "refuses the script without a website" do
    repo.update!(homepage: nil)

    expect(described_class.new(repo: repo, source: "script").call).to be(false)
  end

  it "refuses a second site on Free, unless asked to count it instead" do
    user.update!(pro: false)
    other = create(:github_repo, user: user, homepage: "https://tidepool.dev", site_source: "script")

    expect(described_class.new(repo: repo, source: "script").call).to be(false)
    expect(described_class.new(repo: repo, source: "script", count_here: true).call).to be(true)
    expect([ repo.reload.site_source, other.reload.site_source ]).to eq([ "script", nil ])
  end
end
