require "rails_helper"

RSpec.describe Projects::ShowNumberService do
  let(:repo) { create(:github_repo) }

  it "hides a number from the project's visitors, and shows it again" do
    described_class.new(repo: repo, number: "commits", shown: false).call!
    described_class.new(repo: repo, number: "visits", shown: false).call!
    expect(repo.reload.hidden_numbers).to eq(%w[commits visits])

    described_class.new(repo: repo, number: "commits", shown: true).call!
    expect(repo.reload.hidden_numbers).to eq([ "visits" ])
  end

  it "needs a project" do
    expect(described_class.new(number: "commits", shown: false).call).to be(false)
  end

  it "refuses a number no project shows, such as Openstage's own" do
    service = described_class.new(repo: repo, number: "views", shown: false)

    expect(service.call).to be(false)
    expect(service.errors[:number]).to be_present
    expect(repo.reload.hidden_numbers).to eq([])
  end

  it "needs to know whether to show it or hide it" do
    service = described_class.new(repo: repo, number: "commits", shown: nil)

    expect(service.call).to be(false)
    expect(service.errors[:shown]).to be_present
  end
end
