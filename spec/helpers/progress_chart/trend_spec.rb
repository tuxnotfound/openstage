require "rails_helper"

RSpec.describe ProgressChart::Trend do
  let(:user) { create(:user) }

  before { travel_to Time.utc(2026, 10, 15, 12) }

  def chart(range, repos: [], discs: false)
    described_class.new(Progress::ComposeService.new(user: user, range: range, repos: repos, rolling: true).tap(&:call!).section, discs: discs)
  end

  def commits(repo, at, count = 1)
    count.times { create(:entry, user: user, repo_name: repo, occurred_at: at) }
  end

  def milestone(title, at, repo: nil)
    create(:entry, user: user, entry_type: "milestone", source: "manual", title: title, repo_name: repo, occurred_at: at)
  end

  it "draws each of 30 days as the average of it and the six days before" do
    commits("me/app", Time.utc(2026, 10, 8, 10), 7)
    days = (Date.new(2026, 9, 16)..Date.new(2026, 10, 15)).to_a
    values = chart("30d").lines.first.values

    expect(values.values_at(days.index(Date.new(2026, 10, 7)), days.index(Date.new(2026, 10, 8)), days.index(Date.new(2026, 10, 14)))).to eq([ 0, 1.0, 1.0 ])
    expect(values.last).to eq(0)
  end

  it "counts each week over 90 days and each month over 12, under whole-number gridlines" do
    commits("me/app", Time.utc(2026, 10, 13, 10), 3)
    commits("me/app", Time.utc(2026, 6, 2, 10), 9)

    expect(chart("90d").lines.first.values.last).to eq(3)
    twelve = chart("12m")
    expect(twelve.lines.first.values.values_at(7, 11)).to eq([ 9, 3 ])
    expect(twelve.ticks.map(&:value)).to eq([ 5, 10 ])
    expect(twelve.axis).to eq([ "Nov 2025", "May", "Today" ])
  end

  it "draws the lines alone on a page; discs are the weekly email's" do
    commits("me/app", Time.utc(2026, 10, 13, 10), 4)
    milestone("Shipped", Time.utc(2026, 10, 13, 12), repo: "me/app")

    expect(chart("90d").discs).to be_empty
    expect(chart("90d", discs: true).discs.size).to eq(1)
  end

  it "stands a listed entry's disc on its own project's line, and one with no project in no colour" do
    commits("me/app", Time.utc(2026, 10, 13, 10), 4)
    commits("me/other", Time.utc(2026, 10, 13, 11), 2)
    milestone("Untagged", Time.utc(2026, 9, 1, 12))
    milestone("Other shipped", Time.utc(2026, 10, 13, 12), repo: "me/other")
    trend = chart("90d", discs: true)
    untagged, tagged = trend.discs

    expect([ untagged.number, untagged.rank, untagged.top ]).to eq([ 1, nil, 94 ])
    expect([ tagged.number, tagged.rank, tagged.top ]).to eq([ 2, 1, trend.top(2) ])
  end

  it "moves a disc that would cover another" do
    commits("me/app", Time.utc(2026, 10, 12, 10), 4)
    milestone("First", Time.utc(2026, 10, 13, 12), repo: "me/app")
    milestone("Second", Time.utc(2026, 10, 14, 12), repo: "me/app")
    first, second = chart("90d", discs: true).discs

    expect(second.top).to eq((first.top + 24).round(2))
  end
end
