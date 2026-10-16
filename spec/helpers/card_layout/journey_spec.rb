require "rails_helper"
require "support/progress_data"

RSpec.describe CardLayout::Journey do
  include ProgressData

  let(:user) { create(:user, username: "tuxnotfound", display_name: "Tux") }

  before do
    seed_progress_data(user)
    travel_to ProgressData::TODAY
  end

  def card(range, offset: 0, repo: nil, theme: "light", swapped: [])
    section = Progress::ComposeService.new(user: user, range: range, offset: offset, repos: Array(repo), swapped_ids: swapped)
                                      .tap(&:call!).section
    described_class.new(section, user: user, theme: theme)
  end

  def box(flag)
    [ flag.x, flag.x + flag.shape.w, flag.y, flag.y + flag.shape.h ].map(&:round)
  end

  def words(flag)
    flag.shape.lines.join(" / ").tr("\u00A0", " ")
  end

  it "puts 2026's six flags where the design round measured them" do
    flags = card("year").flags.sort_by { |flag| flag.item.date }

    expect(flags.map { |flag| words(flag) }).to eq([
      "We are live!!", "Share on 𝕏 !", "launched The Goal Atlas — / just in time for 2026", "Rebirth begins",
      "Trained on me is live!!", "What I worked on this week: / 40 commits across 3 repos."
    ])
    measured = { "We are live!!" => [ 175, 294, 505, 529 ], "Share on 𝕏 !" => [ 331, 453, 478, 502 ],
                 "Rebirth begins" => [ 794, 934, 414, 438 ], "Trained on me is live!!" => [ 802, 1014, 383, 407 ] }
    measured.each do |title, expected|
      flag = flags.find { |candidate| words(candidate) == title }
      box(flag).zip(expected).each { |got, want| expect(got).to be_within(3).of(want) }
    end
  end

  it "ends the ink line in a dot with the period's commits beside it" do
    year = card("year")

    expect(year.geometry.line.last.map(&:round)).to eq([ 1079, 330 ])
    expect([ year.geometry.end_box.num, year.geometry.end_box.word ]).to eq([ "380", " commits" ])
    expect([ year.geometry.first, year.geometry.last ]).to eq([ Date.new(2026, 2, 1), Date.new(2026, 10, 31) ])
  end

  it "draws each project's line beneath the ink one with a legend, and only the ink one under a filter" do
    expect(card("year").strokes.size).to eq(8)
    expect(card("year").strokes.last[1]).to eq("#14171A")

    expect(card("year").canvas.runs.map(&:text)).to include("openstage", "176", "trained-on-dataset")

    trained_on = card("year", repo: progress_repo(4))
    expect(trained_on.strokes.size).to eq(1)
    expect(trained_on.fills).to be_empty
    expect(trained_on.wash_paint.first).to eq("#e87ba4")
    expect(trained_on.flags.map { |flag| words(flag) }).to eq([ "Trained on me is live!!" ])
  end

  it "draws the picked projects' lines under their ink total when several are picked" do
    both = card("year", repo: [ progress_repo(0), progress_repo(1) ])

    expect(both.strokes.size).to eq(3)
    expect(both.geometry.total).to eq(176 + 62)
    expect(both.fills.size).to eq(2)
  end

  it "puts what the flags carry on the post, and the rest under Not on the card" do
    year = card("year")

    expect(year.items.map(&:title).first).to eq("We are live!!")
    expect(year.items.size + year.left_out.size).to eq(20)
  end

  it "says so when the period holds nothing" do
    week = card("week")

    expect(week.flags).to be_empty
    expect(week.canvas.runs.map(&:text)).to include("Nothing shipped or published this week yet.", "79")
  end

  it "puts an entry swapped in on the card where the line has room for it" do
    pro_tier = progress_entry(user, 8)

    expect(card("year", swapped: [ pro_tier.id ]).items).to include(have_attributes(id: pro_tier.id))
  end

  it "changes nothing when an entry swapped in fits nowhere on the line" do
    crowded = progress_entry(user, 16)

    expect(card("year", swapped: [ crowded.id ]).items.map(&:id)).to eq(card("year").items.map(&:id))
  end

  it "keys the circles in the stats row and counts the change" do
    october = card("month", theme: "dark")

    expect(october.canvas.runs.map(&:text)).to include("SHIPPED", "PUBLISHED", "150", "+127", "+7")
    expect(october.palette[:pole]).to eq("#4A5258")
  end
end
