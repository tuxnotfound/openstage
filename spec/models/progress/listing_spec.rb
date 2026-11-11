require "rails_helper"

RSpec.describe Progress::Listing do
  it "reads the list's params, and opens a list on an address no one could have meant" do
    listing = described_class.from(sort: "commits", q: "  sauna ", live: "1", page: "3")
    expect([ listing.sort, listing.query, listing.live, listing.page ]).to eq([ "commits", "sauna", true, 3 ])

    odd = described_class.from(sort: "stars", q: "x" * 300, live: "maybe", page: "-2")
    expect([ odd.sort, odd.query.size, odd.live, odd.page ]).to eq([ "latest", 100, false, 1 ])
  end

  it "names itself in an address with its defaults left out" do
    expect(described_class.from({}).to_params).to eq({})
    expect(described_class.from(sort: "name", q: "a", live: "true", page: "2").to_params).to eq(sort: "name", q: "a", live: "1", page: 2)
  end

  it "makes the same listing with one thing changed, and equals another that names the same view" do
    listing = described_class.from(sort: "name", page: "4")

    expect(listing.with(page: 1).to_params).to eq(sort: "name")
    expect(listing.with(live: true)).to eq(described_class.from(sort: "name", live: "1", page: "4"))
  end
end
