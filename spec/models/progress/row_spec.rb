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

  it "has its builder's switch for a number it counts on a synced repo, and Set up for site visits it counts none of" do
    repo = build(:github_repo, hidden_numbers: [ "visits" ])
    row = described_class.new(key: "me/app", name: "app", rank: 0, repo: repo, on: true, counted: %w[commits visits], shown: %w[commits])
    bare = described_class.new(key: "me/lib", name: "lib", rank: 1, repo: repo, on: true, counted: %w[commits], shown: %w[commits])
    unsynced = described_class.new(key: "me/gone", name: "gone", rank: 2, repo: nil, on: true, counted: %w[commits], shown: %w[commits])

    expect([ row.pick("commits"), row.pick("visits"), bare.pick("visits"), unsynced.pick("commits") ]).to eq([ true, false, nil, nil ])
    expect([ row.setup?("visits"), bare.setup?("visits"), bare.setup?("commits"), unsynced.setup?("visits") ]).to eq([ false, true, false, false ])
  end
end
