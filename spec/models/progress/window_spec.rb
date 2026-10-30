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

  it "starts at the first activity's day, week or month when that came inside the window" do
    late = Date.new(2026, 9, 24) # a Thursday

    expect(window("30d", first_activity: late).first).to eq(late)
    expect(window("90d", first_activity: late).first).to eq(Date.new(2026, 9, 21))
    older = Date.new(2026, 6, 10)
    expect([ window("12m", first_activity: older).first, window("12m", first_activity: older).buckets.size ]).to eq([ Date.new(2026, 6, 1), 5 ])
    expect(window("30d", first_activity: late).comparison).to be_nil
  end

  it "draws a history younger than 13 weeks by week in the longer views, never by day" do
    young = Date.new(2026, 9, 24) # a Thursday, three weeks back

    expect([ window("12m", first_activity: young).unit, window("12m", first_activity: young).first ]).to eq([ :week, Date.new(2026, 9, 21) ])
    expect([ window("all", first_activity: young).unit, window("all", first_activity: young).buckets.size ]).to eq([ :week, 4 ])
    expect(window("30d", first_activity: young).unit).to eq(:day)
    expect(window("12m", first_activity: Date.new(2026, 6, 2)).unit).to eq(:month)
  end

  it "opens on the last 30 days for a range it does not know" do
    expect(window("year").range).to eq("30d")
    expect(window(nil).range).to eq("30d")
  end

  it "finds the point a date falls on" do
    expect(window("90d").bucket_for(Date.new(2026, 10, 13)).index).to eq(12)
    expect(window("90d").bucket_for(Date.new(2026, 1, 1))).to be_nil
  end

  describe "days the builder picked" do
    def picked(range, first_activity: early)
      window(range, first_activity: first_activity)
    end

    it "spans them, carries them as its range and compares them with as many days just before" do
      w = picked("2026-10-03..2026-10-12")

      expect([ w.range, w.custom?, w.first, w.last, w.span ]).to eq([ "2026-10-03..2026-10-12", true, Date.new(2026, 10, 3), Date.new(2026, 10, 12), Date.new(2026, 10, 3)..Date.new(2026, 10, 12) ])
      expect(w.span_before).to eq(Date.new(2026, 9, 23)..Date.new(2026, 10, 2))
      expect(w.comparison).to eq(Date.new(2026, 9, 23)..Date.new(2026, 10, 2))
      expect(picked("2026-10-03..2026-10-12", first_activity: Date.new(2026, 10, 5)).comparison).to be_nil
    end

    it "draws up to 31 days by day, up to 26 weeks by ISO week and longer by month" do
      expect(picked("2026-09-15..2026-10-15").unit).to eq(:day)
      expect(picked("2026-09-14..2026-10-15").unit).to eq(:week)
      expect(picked("2026-04-17..2026-10-15").unit).to eq(:week)
      expect(picked("2026-04-16..2026-10-15").unit).to eq(:month)
    end

    it "draws a day by day, the first day picked to the last" do
      w = picked("2026-09-15..2026-10-15")

      expect([ w.buckets.size, w.buckets.first.first, w.buckets.last.last ]).to eq([ 31, Date.new(2026, 9, 15), today ])
    end

    it "cuts its first and last ISO weeks at the days picked" do
      w = picked("2026-09-03..2026-10-07") # a Thursday to a Wednesday

      expect(w.buckets.map { |b| [ b.first, b.last, b.monday ] }.values_at(0, 1, -1)).to eq(
        [ [ Date.new(2026, 9, 3), Date.new(2026, 9, 6), Date.new(2026, 8, 31) ],
          [ Date.new(2026, 9, 7), Date.new(2026, 9, 13), Date.new(2026, 9, 7) ],
          [ Date.new(2026, 10, 5), Date.new(2026, 10, 7), Date.new(2026, 10, 5) ] ])
      expect(w.bucket_for(Date.new(2026, 9, 5)).index).to eq(0)
    end

    it "cuts its first and last months at the days picked" do
      w = picked("2025-10-03..2026-08-20")

      expect([ w.unit, w.buckets.size ]).to eq([ :month, 11 ])
      expect([ w.buckets.first.first, w.buckets.first.last ]).to eq([ Date.new(2025, 10, 3), Date.new(2025, 10, 31) ])
      expect([ w.buckets[1].first, w.buckets.last.first, w.buckets.last.last ]).to eq([ Date.new(2025, 11, 1), Date.new(2026, 8, 1), Date.new(2026, 8, 20) ])
    end

    it "starts at the first activity inside them, and draws a young history by week rather than by month" do
      late = Date.new(2026, 9, 10) # a Thursday

      expect(picked("2026-09-01..2026-09-30", first_activity: late).first).to eq(late)
      expect(picked("2026-08-01..2026-10-15", first_activity: late).first).to eq(Date.new(2026, 9, 7))
      young = picked("2025-01-01..2026-10-15", first_activity: late)
      expect([ young.unit, young.first, young.buckets.size ]).to eq([ :week, Date.new(2026, 9, 7), 6 ])
    end

    it "draws days picked before any work empty, from their own first day" do
      w = picked("2024-01-01..2024-01-10", first_activity: early)

      expect([ w.first, w.buckets.size, w.comparison ]).to eq([ Date.new(2024, 1, 1), 10, nil ])
    end

    it "runs only while it ends today, so a past one marks no point current" do
      expect([ picked("2026-10-01..2026-10-15").running?, picked("2026-10-01..2026-10-15").buckets.last.current ]).to eq([ true, true ])
      past = picked("2026-09-01..2026-09-20")
      expect([ past.running?, past.buckets.any?(&:current) ]).to eq([ false, false ])
    end

    it "ends today at the latest, and opens on the default when it starts after today" do
      expect(picked("2026-10-01..2026-12-31").range).to eq("2026-10-01..2026-10-15")
      expect(picked("2026-11-01..2026-12-31").range).to eq("30d")
      expect(picked("2026-02-30..2026-03-01").range).to eq("30d")
    end

    it "averages each day over a week from 14 days drawn by day, as the 30-day view does" do
      expect([ window("30d"), window("90d") ].map(&:average?)).to eq([ true, false ])
      expect(picked("2026-10-02..2026-10-15").average?).to be(true)
      expect(picked("2026-10-03..2026-10-15").average?).to be(false)
      expect(picked("2026-09-01..2026-10-15").average?).to be(false)
    end
  end

  describe "its words" do
    it "names the window and its points" do
      labels = window("90d").labels

      expect([ labels.words, labels.word ]).to eq([ "last 90 days", "in the last 90 days" ])
      expect(labels.empty).to eq("Nothing shipped or published in the last 90 days.")
      expect(labels.bucket_title(window("90d").buckets.last)).to eq("Week of Oct 12–15")
      expect(labels.axis(window("90d").buckets.first)).to eq("Jul 20")
    end

    it "names days picked by their dates, with years when they are not all in this year" do
      labels = window("2026-10-03..2026-10-12").labels

      expect([ labels.words, labels.span_words, labels.word, labels.before ]).to eq([ "3 Oct – 12 Oct", "3 Oct – 12 Oct", "between 3 Oct and 12 Oct", "the 10 days before" ])
      expect(labels.empty).to eq("Nothing shipped or published between 3 Oct and 12 Oct.")
      expect(labels.empty_tagged("openstage")).to eq("No entries tagged openstage between 3 Oct and 12 Oct.")
      expect(labels.file_name).to eq("2026-10-03-to-2026-10-12")
      expect(window("2025-10-03..2026-01-28").labels.name).to eq("3 Oct 2025 – 28 Jan 2026")
      one = window("2026-10-03..2026-10-03").labels
      expect([ one.name, one.word, one.before ]).to eq([ "3 Oct", "on 3 Oct", "the day before" ])
      expect([ window("90d").labels.name, window("90d").labels.before, window("all").labels.before ]).to eq([ nil, "the 90 days before", nil ])
    end

    it "gives a month cut by the days picked its own days, and a past window's last point its date" do
      w = window("2025-10-03..2026-08-20")

      expect(w.buckets.values_at(0, 1, -1).map { |bucket| w.labels.bucket_title(bucket) }).to eq([ "Oct 3–31, 2025", "November 2025", "Aug 1–20, 2026" ])
      expect(ProgressChart::Compare.new(window: w, lines: [], numbers: []).axis).to eq([ "Oct 2025", "Mar", "Aug" ])
      expect(ProgressChart::Compare.new(window: window("12m"), lines: [], numbers: []).axis.last).to eq("Today")
    end

    it "names a month of another year with its year" do
      labels = window("12m").labels

      expect(window("12m").buckets.map { |bucket| labels.axis(bucket) }.values_at(0, 2, 11)).to eq([ "Nov 2025", "Jan", "Oct" ])
      expect(window("all").labels.words).to eq("since January 2025")
    end
  end
end
