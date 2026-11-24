require "rails_helper"

RSpec.describe Feed::ListService do
  let(:busy) { create(:user, username: "busy") }
  let(:quiet) { create(:user, username: "quiet") }

  before { travel_to Time.utc(2026, 11, 24, 18) }

  def commits(user, count, from)
    count.times.map { |i| create(:entry, user: user, title: "#{user.username} #{i}", occurred_at: from + i.minutes) }
  end

  def list(**cursor)
    described_class.new(scope: Entry.on_feed, per_page: 2, **cursor).tap(&:call!)
  end

  def cards(feed)
    feed.cards.map { |card| [ card.user.username, card.date.iso8601, card.total ] }
  end

  it "puts a builder's whole day in one card, however many entries it holds, so it never crowds out the others" do
    commits(busy, 45, Time.utc(2026, 11, 24, 10))
    commits(quiet, 1, Time.utc(2026, 11, 24, 9))

    feed = list

    expect(cards(feed)).to eq([ [ "busy", "2026-11-24", 45 ], [ "quiet", "2026-11-24", 1 ] ])
    expect(feed.cards.first.entries.map(&:title)).to eq([ "busy 44", "busy 43", "busy 42" ])
    expect(feed.cards.first.more).to eq(42)
  end

  it "reads on from the last card shown, never showing a card twice, and stops at the end" do
    commits(busy, 3, Time.utc(2026, 11, 24, 10))
    commits(quiet, 1, Time.utc(2026, 11, 24, 9))
    commits(busy, 2, Time.utc(2026, 11, 20, 9))

    first = list
    rest = list(**first.next_cursor)

    expect(cards(first)).to eq([ [ "busy", "2026-11-24", 3 ], [ "quiet", "2026-11-24", 1 ] ])
    expect(first.next_cursor).to eq(before: "2026-11-24T09:00:00.000000Z", builder: quiet.id)
    expect(cards(rest)).to eq([ [ "busy", "2026-11-20", 2 ] ])
    expect(rest.next_cursor).to be_nil
  end

  it "reads on inside a day when the page ends there" do
    others = 3.times.map { |i| create(:user, username: "builder#{i}") }
    others.each_with_index { |user, i| commits(user, 1, Time.utc(2026, 11, 24, 12 - i)) }

    first = list
    rest = list(**first.next_cursor)

    expect(cards(first).map(&:first)).to eq(%w[builder0 builder1])
    expect(cards(rest).map(&:first)).to eq(%w[builder2])
  end

  it "counts a day's commits, what shipped and what was published" do
    commits(busy, 2, Time.utc(2026, 11, 24, 10))
    create(:entry, user: busy, entry_type: "milestone", source: "manual", occurred_at: Time.utc(2026, 11, 24, 11))
    create(:entry, user: busy, entry_type: "posted", source: "manual", occurred_at: Time.utc(2026, 11, 24, 12))

    card = list.cards.first

    expect([ card.commits, card.shipped, card.published, card.total ]).to eq([ 2, 1, 1, 4 ])
  end

  it "refuses a cursor that is not a time" do
    feed = described_class.new(scope: Entry.on_feed, before: "yesterday", builder: "1")

    expect(feed.call).to be(false)
    expect(feed.errors).to include(:before)
  end

  it "refuses a cursor's builder that is not an id" do
    feed = described_class.new(scope: Entry.on_feed, before: "2026-11-24T09:00:00Z", builder: "busy")

    expect(feed.call).to be(false)
    expect(feed.errors).to include(:builder)
  end

  it "needs the entries to show" do
    expect(described_class.new.call).to be(false)
  end
end
