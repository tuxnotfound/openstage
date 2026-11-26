require "rails_helper"

RSpec.describe Feed::LatelyService do
  before { travel_to Time.utc(2026, 11, 24, 18) }

  it "keeps one line from a project whose script commits all day, and shows the others" do
    busy = create(:user, username: "busy")
    70.times do |i|
      create(:entry, user: busy, repo_name: "busy/site", title: "live numbers sync #{i}", occurred_at: Time.utc(2026, 11, 24, 6) + (i * 5).minutes)
    end
    bob = create(:user, username: "bob")
    create(:entry, user: bob, entry_type: "milestone", source: "manual", title: "Bob's launch", occurred_at: Time.utc(2026, 11, 23, 9))

    lately = described_class.new.tap(&:call!)

    expect(lately.entries.map(&:title)).to eq([ "live numbers sync 69", "Bob's launch" ])
  end

  it "keeps three from a builder at most, each from another project" do
    busy = create(:user, username: "busy")
    %w[a b c d].each_with_index do |repo, i|
      create(:entry, user: busy, repo_name: "busy/#{repo}", title: "Work on #{repo}", occurred_at: Time.utc(2026, 11, 24, 12) - i.hours)
    end
    create(:entry, user: busy, repo_name: "busy/a", title: "Earlier work on a", occurred_at: Time.utc(2026, 11, 24, 7))

    lately = described_class.new.tap(&:call!)

    expect(lately.entries.map(&:title)).to eq([ "Work on a", "Work on b", "Work on c" ])
  end
end
