require "rails_helper"

RSpec.describe Progress::Window do
  let(:today) { Date.new(2026, 10, 15) } # a Thursday
  let(:early) { Date.new(2025, 1, 6) }

  def window(range, first_activity: early)
    described_class.new(range: range, today: today, first_activity: first_activity)
  end

  it "spans the last 30 days by day, against the 30 before them" do
    w = window("30d")

    expect([ w.first, w.last, w.unit, w.buckets.size ]).to eq([ Date.new(2026, 9, 16), today, :day, 30 ])
    expect(w.comparison).to eq(Date.new(2026, 8, 17)..Date.new(2026, 9, 15))
  end

  it "spans 13 ISO weeks by week, this one cut at today, against the 13 before" do
    w = window("90d")

    expect(w.first).to eq(Date.new(2026, 7, 20))
    expect(w.buckets.size).to eq(13)
    expect([ w.buckets.last.first, w.buckets.last.last ]).to eq([ Date.new(2026, 10, 12), today ])
    expect(w.comparison).to eq(Date.new(2026, 4, 20)..Date.new(2026, 7, 16))
  end

  it "spans 12 months by month, this one cut at today, against the year before" do
    w = window("12m")

    expect([ w.first, w.buckets.size, w.buckets.last.last ]).to eq([ Date.new(2025, 11, 1), 12, today ])
    expect(w.comparison).to eq(Date.new(2024, 11, 1)..Date.new(2025, 10, 15))
  end

  it "spans all time from the first activity's month, with nothing to compare" do
    w = window("all")

    expect([ w.first, w.buckets.size, w.comparison ]).to eq([ Date.new(2025, 1, 1), 22, nil ])
  end

  it "compares nothing when the builder's work began inside the window" do
    expect(window("12m", first_activity: Date.new(2026, 3, 26)).comparison).to be_nil
    expect(window("30d", first_activity: nil).comparison).to be_nil
  end

  it "opens on the last 12 months for a range it does not know" do
    expect(window("year").range).to eq("12m")
  end

  it "finds the point a date falls on" do
    expect(window("90d").bucket_for(Date.new(2026, 10, 13)).index).to eq(12)
    expect(window("90d").bucket_for(Date.new(2026, 1, 1))).to be_nil
  end

  describe "its words" do
    it "names the window, what it is measured against, and its points" do
      labels = window("90d").labels

      expect([ labels.words, labels.word, labels.versus ]).to eq([ "last 90 days", "in the last 90 days", "vs the previous 90 days" ])
      expect(labels.empty).to eq("Nothing shipped or published in the last 90 days.")
      expect(labels.bucket_title(window("90d").buckets.last)).to eq("Week of Oct 12–15")
      expect(labels.axis(window("90d").buckets.first)).to eq("Jul 20")
    end

    it "names a month of another year with its year" do
      labels = window("12m").labels

      expect(window("12m").buckets.map { |bucket| labels.axis(bucket) }.values_at(0, 2, 11)).to eq([ "Nov 2025", "Jan", "Oct" ])
      expect([ window("all").labels.words, window("all").labels.versus ]).to eq([ "since January 2025", nil ])
    end
  end
end
