require "rails_helper"

RSpec.describe ProgressChart::Email do
  # Friday of Week 43, which runs Mon Oct 19 to today.
  before { travel_to Time.utc(2026, 10, 23, 13) }

  let(:user) { create(:user) }

  def commits(count, repo, on:)
    count.times { |i| create(:entry, user: user, title: "#{repo} #{i}", repo_name: repo, occurred_at: on) }
  end

  def chart
    described_class.new(Progress::ComposeService.new(user: user, range: "week").tap(&:call!).section)
  end

  it "has one column per day so far, labelled as the page's axis, today in ink" do
    commits(1, "me/app", on: 1.day.ago)

    expect(chart.days.map(&:label)).to eq([ "Mon 19", "Tue 20", "Wed 21", "Thu 22", "Fri 23" ])
    expect(chart.days.map(&:current)).to eq([ false, false, false, false, true ])
  end

  it "stacks the busiest project of all time at the bottom, the busiest day at full height" do
    commits(6, "me/app", on: 1.day.ago)
    commits(2, "me/site", on: 1.day.ago)
    commits(10, "me/app", on: 2.weeks.ago)

    thursday = chart.days[3]
    expect(thursday.segments.map(&:color)).to eq([ ProgressChart::Palette.project_color(1), ProgressChart::Palette.project_color(0) ])
    expect(thursday.segments.sum(&:height)).to eq(described_class::BAR_HEIGHT)
  end

  it "keeps a lone commit visible beside a busy day" do
    commits(1, "me/app", on: 4.days.ago)
    commits(50, "me/app", on: 1.day.ago)

    expect(chart.days.first.segments.map(&:height)).to eq([ described_class::MIN_SEGMENT ])
  end

  it "stands each of the page's discs over its own day" do
    commits(3, "me/app", on: 2.days.ago)
    create(:entry, user: user, entry_type: "milestone", source: "manual", title: "Opened the beta", occurred_at: 2.days.ago)
    create(:entry, user: user, entry_type: "note", source: "manual", title: "Wrote it up", occurred_at: 1.day.ago)

    expect(chart.days.map { |day| day.discs.map(&:label) }).to eq([ [], [], [ "1" ], [ "2" ], [] ])
    expect(chart.days[2].discs.first).to be_shipped
    expect(chart.days[3].discs.first).not_to be_shipped
  end

  it "leaves a day without commits empty" do
    commits(3, "me/app", on: 1.day.ago)

    expect(chart.days.first.segments).to be_empty
  end
end
