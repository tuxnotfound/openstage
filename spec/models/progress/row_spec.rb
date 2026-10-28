require "rails_helper"

RSpec.describe Progress::Row do
  it "says which numbers it counts and which of them it shows" do
    row = described_class.new(key: "me/app", name: "app", rank: 0, repo: nil, on: true, counted: %w[commits visits], shown: %w[commits])

    expect([ row.counts?("visits"), row.shows?("visits"), row.shows?("commits"), row.counts?("views") ]).to eq([ true, false, true, false ])
  end
end
