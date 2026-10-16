require "rails_helper"
require "support/progress_data"

RSpec.describe Progress::ComposeService do
  include ProgressData

  let(:user) { create(:user) }

  before { travel_to ProgressData::TODAY }

  it "counts the period, picks its entries and names its project" do
    seed_progress_data(user)
    service = described_class.new(user: user, range: "year", repo: progress_repo(4))

    expect(service.call).to be(true)
    expect(service.section.tally.totals.commits).to eq(31)
    expect(service.section.pick.kept.map(&:title)).to eq([ "Trained on me is live!!" ])
    expect([ service.section.project.name, service.section.labels.title ]).to eq([ "trained-on", "2026" ])
  end

  it "draws an empty period for a builder with no activity yet" do
    section = described_class.new(user: user, range: "all").tap(&:call!).section

    expect([ section.tally.totals.commits, section.pick.kept, section.labels.title ]).to eq([ 0, [], "All time" ])
    expect(section.tally.period.buckets.size).to eq(1)
  end

  it "refuses without a builder" do
    expect(described_class.new(range: "year").call).to be(false)
  end
end
