require "rails_helper"
require "support/progress_data"

RSpec.describe Progress::GatherService do
  include ProgressData

  let(:user) { create(:user) }

  before do
    seed_progress_data(user)
    travel_to ProgressData::TODAY
  end

  it "gathers the window, a card per project and the latest commits by project and day" do
    service = described_class.new(user: user, range: "90d", repos: [ progress_repo(0) ])

    expect(service.call).to be(true)
    expect(service.section.labels.words).to eq("last 90 days")
    expect(service.section.selected.map(&:name)).to eq([ "openstage" ])
    expect(service.cards.map(&:name)).to eq(ProgressData::DATA["projects"].first(service.cards.size))
    expect(service.recent.size).to eq(8)
    expect(service.recent.map { |group| group.project.name }.uniq).to eq([ "openstage" ])
    expect(service.recent.map(&:date)).to eq(service.recent.map(&:date).sort.reverse)
  end

  it "lists no commit of a project whose builder hides them, and keeps its card" do
    shown = described_class.new(user: user).tap(&:call!)
    expect(shown.recent.map { |group| group.project.repo }).to include(progress_repo(0))

    create(:github_repo, user: user, full_name: progress_repo(0), name: "openstage", hidden_numbers: [ "commits" ])
    hiding = described_class.new(user: user).tap(&:call!)

    expect(hiding.recent.size).to eq(8)
    expect(hiding.recent.map { |group| group.project.repo }).not_to include(progress_repo(0))
    expect(hiding.cards.map(&:repo)).to include(progress_repo(0))
  end

  it "opens on the last 12 months" do
    expect(described_class.new(user: user).tap(&:call!).section.labels.range).to eq("12m")
  end

  it "refuses without a builder" do
    expect(described_class.new(range: "30d").call).to be(false)
  end
end
