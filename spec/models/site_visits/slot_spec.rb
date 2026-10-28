require "rails_helper"

RSpec.describe SiteVisits::Slot do
  let(:user) { create(:user) }

  def project(name, set_up: nil, script: true)
    create(:github_repo, user: user, name: name, homepage: "https://#{name}.example", site_source: ("script" if script), site_set_up_at: set_up)
  end

  def slot
    described_class.new(user.reload)
  end

  it "counts the one project set up on Free, and offers no other" do
    lunchbox = project("lunchbox", set_up: 2.days.ago)
    tidepool = project("tidepool", script: false)

    expect(slot.repo).to eq(lunchbox)
    expect([ slot.counts?(lunchbox), slot.state(lunchbox), slot.instead_of(lunchbox) ]).to eq([ true, :counting, nil ])
    expect([ slot.counts?(tidepool), slot.state(tidepool), slot.instead_of(tidepool) ]).to eq([ false, :off, lunchbox ])
  end

  it "lets the first project be set up while none is" do
    expect([ slot.repo, slot.instead_of(project("lunchbox", script: false)) ]).to eq([ nil, nil ])
  end

  it "keeps counting the project set up first after Pro, and pauses every other" do
    user.update!(pro: true)
    lunchbox = project("lunchbox", set_up: 10.days.ago)
    tidepool = project("tidepool", set_up: 3.days.ago)
    expect([ slot.state(lunchbox), slot.state(tidepool) ]).to eq(%i[counting counting])

    user.update!(pro: false)
    expect([ slot.state(lunchbox), slot.state(tidepool) ]).to eq(%i[counting paused])
    expect([ slot.instead_of(lunchbox), slot.instead_of(tidepool) ]).to eq([ nil, lunchbox ])
  end

  it "keeps the slot with the first project while its script is off, so nothing counts" do
    lunchbox = project("lunchbox", set_up: 10.days.ago, script: false)
    tidepool = project("tidepool", set_up: 3.days.ago)

    expect([ slot.state(lunchbox), slot.state(tidepool) ]).to eq(%i[off paused])
    expect([ slot.instead_of(lunchbox), slot.instead_of(tidepool) ]).to eq([ nil, lunchbox ])
  end

  it "frees the slot when its project is deleted, for the next set up" do
    project("lunchbox", set_up: 10.days.ago).destroy!
    tidepool = project("tidepool", set_up: 3.days.ago)

    expect([ slot.repo, slot.state(tidepool) ]).to eq([ tidepool, :counting ])
  end

  it "breaks a tie in setup times by the older project" do
    at = 3.days.ago
    first = project("lunchbox", set_up: at)
    project("tidepool", set_up: at)

    expect(slot.repo).to eq(first)
  end

  it "counts every project set up on Pro, and refuses none" do
    user.update!(pro: true)
    projects = [ project("lunchbox", set_up: 10.days.ago), project("tidepool", set_up: 3.days.ago), project("quiet", script: false) ]

    expect(projects.map { |each| slot.state(each) }).to eq(%i[counting counting off])
    expect(projects.map { |each| slot.instead_of(each) }).to eq([ nil, nil, nil ])
  end

  it "reads the slot once for a list of projects" do
    projects = [ project("lunchbox", set_up: 10.days.ago), project("tidepool", set_up: 3.days.ago), project("quiet") ]
    each = slot
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { projects.each { |one| each.counts?(one) && each.state(one) } }

    expect(queries).to eq(1)
  end
end
