require "rails_helper"

RSpec.describe ShareCards::GatherService do
  let(:user) { create(:user, username: "builder") }
  let(:avatar) { "https://avatars.githubusercontent.com/u/1?s=192" }

  before do
    create(:github_repo, user: user, full_name: "builder/app", description: "A tool for builders.")
    create(:github_repo, user: user, full_name: "builder/side")
    2.times { |i| create(:entry, user: user, repo_name: "builder/app", occurred_at: (i + 1).days.ago) }
    create(:entry, user: user, repo_name: "builder/side", occurred_at: 3.days.ago)
  end

  it "gathers the builder's cards, in the page's order, and their avatar" do
    stub_request(:get, avatar).to_return(status: 200, headers: { "Content-Type" => "image/png" }, body: "PNGBYTES")
    service = described_class.new(user: user)

    expect(service.call).to be(true)
    expect(service.cards.map { |card| [ card.name, card.commits ] }).to eq([ [ "app", 2 ], [ "side", 1 ] ])
    expect(service.avatar).to eq("PNGBYTES")
  end

  it "gathers one project's card for its card" do
    stub_request(:get, avatar).to_return(status: 200, body: "PNGBYTES")
    service = described_class.new(user: user, slug: "APP")

    expect(service.call).to be(true)
    expect(service.cards.map(&:name)).to eq([ "app" ])
    expect(service.cards.first.description).to eq("A tool for builders.")
  end

  it "goes on without the avatar when GitHub fails to give it, and reports why" do
    stub_request(:get, avatar).to_return(status: 503)
    allow(Rails.error).to receive(:report)
    service = described_class.new(user: user)

    expect(service.call).to be(true)
    expect(service.avatar).to be_nil
    expect(Rails.error).to have_received(:report).with(instance_of(ApplicationGateway::ServerError), handled: true)
  end

  it "refuses a project that is not on the builder's page" do
    service = described_class.new(user: user, slug: "nope")

    expect(service.call).to be(false)
    expect(service.errors[:slug]).to be_present
  end

  it "refuses without a builder" do
    expect(described_class.new.call).to be(false)
  end
end
