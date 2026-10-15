require "rails_helper"

RSpec.describe Progress::PeriodLabels do
  def labels(range, offset = 0)
    described_class.new(Progress::Period.new(range: range, offset: offset, today: Date.new(2026, 10, 15), first_activity: Date.new(2026, 3, 23)))
  end

  it "heads each range the way the mocks do" do
    expect([ labels("week").title, labels("week").subtitle ]).to eq([ "Week 42", "Oct 12–18, 2026 · so far" ])
    expect([ labels("month").title, labels("month").subtitle ]).to eq([ "October 2026", "Oct 1–15 · so far" ])
    expect([ labels("month", -1).subtitle, labels("year").subtitle ]).to eq([ "Sep 1–30", "Jan 1 – Oct 15 · so far" ])
    expect([ labels("all").title, labels("all").subtitle ]).to eq([ "All time", "Since March 2026" ])
  end

  it "names the card's tag and file" do
    expect([ labels("week").tag, labels("all").tag ]).to eq([ "PROGRESS · WEEK", "PROGRESS · ALL TIME" ])
    expect([ labels("week").file_name, labels("month").file_name, labels("year").file_name ]).to eq(%w[2026-w42 2026-10 2026])
  end

  it "says what is empty, and adds yet only while the period runs" do
    expect(labels("week").empty).to eq("Nothing shipped or published this week yet.")
    expect(labels("week", -1).empty).to eq("Nothing shipped or published in Week 41.")
    expect(labels("all").empty).to eq("Nothing shipped or published so far.")
    expect(labels("year").empty_tagged("openstage")).to eq("No entries tagged openstage in 2026.")
    expect(labels("all").empty_tagged("openstage")).to eq("No entries tagged openstage yet.")
  end

  it "names what the change is measured against" do
    expect(labels("week").versus).to eq("vs Mon–Thu last week")
    expect(labels("week", -1).versus).to eq("vs Week 40")
    expect(labels("month").versus).to eq("vs Sep 1–15")
    expect(labels("month", -1).versus).to eq("vs August")
    expect(labels("year").versus).to be_nil
  end

  it "labels the axis sparsely" do
    month = labels("month")
    expect(month.period.buckets.map { |bucket| month.axis(bucket) }.reject(&:empty?)).to eq([ "Oct 1", "8", "15", "22", "29" ])

    year = labels("year")
    expect(year.period.buckets.map { |bucket| year.axis(bucket) }.reject(&:empty?)).to eq(%w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec])

    all = labels("all")
    expect(all.period.buckets.map { |bucket| all.axis(bucket) }).to eq([ "Mar 2026", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct" ])
    expect(labels("week").axis(labels("week").period.buckets.first)).to eq("Mon 12")
  end

  it "titles a bucket for its tooltip" do
    expect(labels("month").bucket_title(labels("month").period.buckets.first)).to eq("Thu, Oct 1")
    expect(labels("year").bucket_title(labels("year").period.buckets[41])).to eq("Week of Oct 12–18")
    expect(labels("all").bucket_title(labels("all").period.buckets.last)).to eq("October 2026")
  end
end
