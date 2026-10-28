require "rails_helper"

RSpec.describe SiteVisits::ConfigureService do
  let(:user) { create(:user, pro: true) }
  let(:repo) { create(:github_repo, user: user, name: "shipnote", homepage: "https://shipnote.app") }

  def configure(project, source)
    described_class.new(repo: project, source: source)
  end

  it "sets up the script with a token that stays when it is turned off and on" do
    configure(repo, "script").call!
    token = repo.reload.site_token

    configure(repo, "off").call!
    configure(repo, "script").call!

    expect(repo.reload).to have_attributes(site_source: "script", site_token: token)
  end

  it "keeps the time it was first set up, whatever comes after" do
    set_up = Time.utc(2026, 10, 20, 9)
    travel_to(set_up) { configure(repo, "script").call! }

    configure(repo, "off").call!
    user.update!(pro: false)
    configure(repo, "script").call!

    expect(repo.reload.site_set_up_at).to eq(set_up)
  end

  it "needs a project" do
    expect(described_class.new(source: "script").call).to be(false)
  end

  it "refuses a source it does not know" do
    service = configure(repo, "vercel")

    expect(service.call).to be(false)
    expect(service.errors[:source]).to be_present
  end

  it "refuses the script without a website" do
    repo.update!(homepage: nil)

    expect(configure(repo, "script").call).to be(false)
  end

  describe "on Free" do
    let(:user) { create(:user, pro: false) }
    let(:other) { create(:github_repo, user: user, name: "tidepool", homepage: "https://tidepool.dev") }

    it "sets up one project for life, and refuses any other with the Pro prompt" do
      configure(repo, "script").call!
      service = configure(other, "script")

      expect(service.call).to be(false)
      expect(service.errors.full_messages).to eq([ "Free counts site visits for one project, shipnote. Go Pro to count them for every project." ])
      expect(other.reload).to have_attributes(site_source: nil, site_token: nil, site_set_up_at: nil)
    end

    it "lets that project turn its script off and on, and keeps the others refused meanwhile" do
      configure(repo, "script").call!
      configure(repo, "off").call!

      expect(configure(other, "script").call).to be(false)
      expect(configure(repo, "script").call).to be(true)
    end

    it "refuses a project paused since Pro ended to start again, and lets it turn off" do
      repo.update!(site_source: "script", site_token: "os_s", site_set_up_at: 10.days.ago)
      other.update!(site_source: "script", site_token: "os_t", site_set_up_at: 3.days.ago)

      expect(configure(other, "script").call).to be(false)
      expect(configure(other, "off").call).to be(true)
      expect(other.reload).to have_attributes(site_source: nil, site_set_up_at: be_present)
    end

    it "frees the slot when its project is deleted" do
      configure(repo, "script").call!
      repo.destroy!

      expect(configure(other, "script").call).to be(true)
    end
  end

  it "sets up every project on Pro" do
    other = create(:github_repo, user: user, name: "tidepool", homepage: "https://tidepool.dev")

    expect([ configure(repo, "script").call, configure(other, "script").call ]).to eq([ true, true ])
  end
end
