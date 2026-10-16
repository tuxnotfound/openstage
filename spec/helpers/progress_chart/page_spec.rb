require "rails_helper"
require "support/progress_data"

RSpec.describe ProgressChart::Page do
  include ProgressData

  let(:user) { create(:user) }

  before do
    seed_progress_data(user)
    travel_to ProgressData::TODAY
  end

  def chart(range, offset: 0, repo: nil)
    section = Progress::ComposeService.new(user: user, range: range, offset: offset, repo: repo).tap(&:call!).section
    described_class.new(section)
  end

  def placed(discs)
    discs.map { |disc| [ disc.label, disc.bucket_index ] }
  end

  it "puts a disc or a pill on each listed entry's week in 2026" do
    expect(placed(chart("year").discs)).to eq([ [ "1", 13 ], [ "2–3", 18 ], [ "4", 23 ], [ "5", 36 ], [ "6", 39 ] ])
  end

  it "puts pills on the days holding several entries in Week 13" do
    expect(placed(chart("week", offset: -29).discs)).to eq([ [ "1", 0 ], [ "2–3", 3 ], [ "4", 4 ], [ "5–6", 5 ] ])
  end

  it "fills a disc when its bucket holds a shipped entry" do
    expect(chart("month").discs.map(&:shipped?)).to eq([ true, false, false ])
  end

  it "never lets two discs touch, and keeps every disc inside the plot" do
    discs = chart("year").discs
    discs.each_cons(2) { |a, b| expect(b.x - a.x).to be >= ((a.width + b.width) / 2.0) + 3 - 1e-9 }
    discs.each { |disc| expect(disc.x - (disc.width / 2.0)).to be >= described_class::FRAME.left }
  end

  it "stands a disc just above the tallest bar it touches" do
    october = chart("month")
    third = october.discs.last

    expect(third.cy).to be < described_class::FRAME.bottom - 4
    expect(chart("week").discs).to be_empty
  end

  it "keeps the top tick and the plot height in every period" do
    expect(chart("year").ticks.map(&:value)).to eq([ 0, 50, 100 ])
    expect(chart("week").ticks.last.top).to eq(chart("year").ticks.last.top)
  end

  it "titles each hover column and leads its entries with their disc" do
    may = chart("year").columns[18]

    expect([ may.title, may.total ]).to eq([ "Week of May 4–10", "55 commits" ])
    expect(may.rows.map(&:n)).to eq([ 35, 20 ])
    expect(may.notes.map(&:mark)).to eq(%w[· 2 3])
  end

  it "names the current month on the Year axis and quiets the months ahead" do
    labels = chart("year").labels

    expect(labels.find { |label| label.text == "Oct" }.tone).to eq(:now)
    expect(labels.find { |label| label.text == "Nov" }.tone).to eq(:future)
  end

  it "lists the period's projects for the legend, but not under a filter" do
    expect(chart("year").legend.map(&:name).first(2)).to eq(%w[openstage wheels-off])
    expect(chart("year", repo: progress_repo(4)).legend).to be_nil
  end
end
