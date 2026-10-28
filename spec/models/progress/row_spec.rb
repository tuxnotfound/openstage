require "rails_helper"

RSpec.describe Progress::Row do
  it "says which numbers it counts and which of them it shows" do
    row = described_class.new(key: "me/app", name: "app", rank: 0, repo: nil, on: true, counted: %w[commits visits], shown: %w[commits])

    expect([ row.counts?("visits"), row.shows?("visits"), row.shows?("commits"), row.counts?("views") ]).to eq([ true, false, true, false ])
  end

  it "lists for visitors what it shows, and for its builder what it counts too" do
    row = described_class.new(key: "me/app", name: "app", rank: 0, repo: nil, on: true, counted: %w[commits visits], shown: %w[commits])

    expect([ row.lists?("visits", false), row.lists?("visits", true), row.lists?("views", true) ]).to eq([ false, true, false ])
  end

  it "has its builder's switch for a number it counts on a synced repo, and for site visits only while they count" do
    repo = build(:github_repo, hidden_numbers: [ "visits" ])
    row = ->(site, counted = %w[commits visits]) { described_class.new(key: "me/app", name: "app", rank: 0, repo: repo, on: true, counted: counted, shown: %w[commits], site: site) }
    unsynced = described_class.new(key: "me/gone", name: "gone", rank: 2, repo: nil, on: true, counted: %w[commits], shown: %w[commits])

    expect([ row.call(:counting).pick("commits"), row.call(:counting).pick("visits"), unsynced.pick("commits") ]).to eq([ true, false, nil ])
    expect([ row.call(:paused).pick("visits"), row.call(:off).pick("visits"), row.call(:counting, %w[commits]).pick("visits") ]).to eq([ nil, nil, nil ])
  end

  it "puts Paused in the switch's place while Free counts another project, and Set up while its site visits count none" do
    repo = build(:github_repo)
    row = ->(site, counted = %w[commits visits]) { described_class.new(key: "me/app", name: "app", rank: 0, repo: repo, on: true, counted: counted, shown: %w[commits], site: site) }
    unsynced = described_class.new(key: "me/gone", name: "gone", rank: 2, repo: nil, on: true, counted: %w[commits], shown: %w[commits])

    expect(%i[counting paused off].map { |site| row.call(site).link("visits") }).to eq([ nil, :paused, :set_up ])
    expect([ row.call(:counting, %w[commits]).link("visits"), row.call(:paused).link("commits"), unsynced.link("visits") ]).to eq([ :set_up, nil, nil ])
  end
end
