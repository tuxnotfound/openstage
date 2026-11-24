require "rails_helper"

RSpec.describe Feed::LatelyService do
  before { travel_to Time.utc(2026, 11, 24, 18) }

  it "keeps three from a builder whose script commits all day, and shows the others" do
    busy = create(:user, username: "busy")
    70.times { |i| create(:entry, user: busy, title: "live numbers sync #{i}", occurred_at: Time.utc(2026, 11, 24, 6) + (i * 5).minutes) }
    bob = create(:user, username: "bob")
    create(:entry, user: bob, entry_type: "milestone", source: "manual", title: "Bob's launch", occurred_at: Time.utc(2026, 11, 23, 9))

    lately = described_class.new.tap(&:call!)

    expect(lately.entries.map(&:title)).to eq([ "live numbers sync 69", "live numbers sync 68", "live numbers sync 67", "Bob's launch" ])
  end
end
