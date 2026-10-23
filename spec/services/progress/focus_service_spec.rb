require "rails_helper"
require "support/progress_data"

RSpec.describe Progress::FocusService do
  include ProgressData

  let(:user) { create(:user) }

  before do
    seed_progress_data(user)
    travel_to ProgressData::TODAY
  end

  it "gathers one project's page, its card, the others and its latest highlight" do
    service = described_class.new(user: user, slug: "Trained-On", range: "90d")

    expect(service.call).to be(true)
    expect(service.project.repo).to eq(progress_repo(4))
    expect(service.page.section.selected.map(&:name)).to eq([ "trained-on" ])
    expect(service.card.repo).to eq(progress_repo(4))
    expect(service.others.map(&:repo)).not_to include(progress_repo(4))
    expect(service.news.repo_name).to eq(progress_repo(4))
    expect(service.highlights).to eq(user.entries.highlights.where(repo_name: progress_repo(4)).count)
    expect(service.first_commit).to eq(user.entries.commits.where(repo_name: progress_repo(4)).minimum(:occurred_at))
  end

  it "refuses a name that is no project on the page" do
    service = described_class.new(user: user, slug: "nope")

    expect(service.call).to be(false)
    expect(service.errors[:slug]).to be_present
  end

  it "refuses without a builder or a name" do
    expect(described_class.new(slug: "openstage").call).to be(false)
    expect(described_class.new(user: user).call).to be(false)
  end
end
