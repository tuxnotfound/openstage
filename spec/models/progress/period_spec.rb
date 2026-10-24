require "rails_helper"

RSpec.describe Progress::Period do
  let(:today) { Date.new(2026, 10, 15) }
  let(:first_activity) { Date.new(2026, 3, 23) }

  def period(range, offset = 0)
    described_class.new(range: range, offset: offset, today: today, first_activity: first_activity)
  end

  it "runs an ISO week from Monday, a day per bucket, up to today" do
    week = period("week")

    expect([ week.first, week.last, week.unit ]).to eq([ Date.new(2026, 10, 12), Date.new(2026, 10, 18), :day ])
    expect(week.buckets.map(&:first)).to eq((Date.new(2026, 10, 12)..Date.new(2026, 10, 15)).to_a)
    expect(week.buckets.map(&:current)).to eq([ false, false, false, true ])
    expect(period("week", -1).buckets.size).to eq(7)
  end

  it "steps back a week, a month or a year by offset, never forward" do
    expect(period("week", -1).first).to eq(Date.new(2026, 10, 5))
    expect([ period("month", -1).first, period("month", -1).last ]).to eq([ Date.new(2026, 9, 1), Date.new(2026, 9, 30) ])
    expect(period("year", -1).first).to eq(Date.new(2025, 1, 1))
    expect(period("week", 3).first).to eq(Date.new(2026, 10, 12))
  end

  # The first activity is Mar 23, so this year's chart starts that week.
  it "cuts a year into ISO weeks clipped to the year, up to today, from the first activity" do
    year = period("year")

    expect(year.buckets.size).to eq(30)
    expect(year.buckets.first).to have_attributes(first: Date.new(2026, 3, 23), last: Date.new(2026, 3, 29), monday: Date.new(2026, 3, 23))
    expect(year.buckets.last).to have_attributes(first: Date.new(2026, 10, 12), last: Date.new(2026, 10, 15), current: true)
    expect(period("year", -1).buckets.last).to have_attributes(first: Date.new(2025, 12, 29), last: Date.new(2025, 12, 31))
  end

  it "starts the week's chart at the first activity when that came mid-week, its dates unchanged" do
    week = described_class.new(range: "week", offset: 0, today: today, first_activity: Date.new(2026, 10, 14))

    expect([ week.first, week.buckets.first.first, week.buckets.size ]).to eq([ Date.new(2026, 10, 12), Date.new(2026, 10, 14), 2 ])
  end

  it "runs all time by month from the month of the first activity" do
    all = period("all", -2)

    expect([ all.offset, all.first, all.last, all.unit ]).to eq([ 0, Date.new(2026, 3, 1), Date.new(2026, 10, 31), :month ])
    expect(all.buckets.map(&:first).map(&:month)).to eq((3..10).to_a)
    expect(all.buckets.last.last).to eq(today)
    expect(all.previous).to be_nil
  end

  it "compares a running period with the same span of the one before" do
    expect(period("month").comparison).to eq(Date.new(2026, 9, 1)..Date.new(2026, 9, 15))
    expect(period("week").comparison).to eq(Date.new(2026, 10, 5)..Date.new(2026, 10, 8))
    expect(period("month", -1).comparison).to eq(Date.new(2026, 8, 1)..Date.new(2026, 8, 31))
  end

  it "has nothing to compare with before the first activity" do
    expect(period("year").comparison).to be_nil
    expect(period("month", -7).previous?).to be(false)
    expect(period("all").comparison).to be_nil
  end

  it "ends the domain today while the period runs" do
    expect(period("year").last_day).to eq(today)
    expect(period("month", -1).last_day).to eq(Date.new(2026, 9, 30))
  end

  it "falls back to Year for a range it does not know" do
    expect(period("decade").range).to eq("year")
  end
end
