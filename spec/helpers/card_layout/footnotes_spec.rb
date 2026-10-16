require "rails_helper"
require "support/progress_data"

RSpec.describe CardLayout::Footnotes do
  include ProgressData

  let(:user) { create(:user, username: "tuxnotfound", display_name: "Tux") }

  before do
    seed_progress_data(user)
    travel_to ProgressData::TODAY
  end

  def card(range, offset: 0, repo: nil, theme: "light", swapped: [], kind: :bars)
    section = Progress::ComposeService.new(user: user, range: range, offset: offset, repos: Array(repo), swapped_ids: swapped)
                                      .tap(&:call!).section
    described_class.new(section, user: user, theme: theme, kind: kind)
  end

  def lines(note)
    note.lines.map { |line| "#{line.text}#{line.run}".tr(" ", " ") }
  end

  def texts(layout)
    layout.canvas.runs.map(&:text)
  end

  it "sets 2026's six notes at 28px, the dash kept with the word before it" do
    year = card("year")

    expect(year.fit.size).to eq(28)
    expect(year.fit.notes.map { |note| lines(note) }).to eq([
      [ "live on Hacker News" ], [ "story time is live!" ], [ "Share on 𝕏 !" ],
      [ "launched The Goal Atlas —", "just in time for 2026" ], [ "Rebirth begins" ], [ "Trained on me is live!!" ]
    ])
    expect(year.fit.notes.map { |note| note.lines.last.star }).to eq([ false, false, false, false, true, true ])
  end

  it "runs a build log's body on after its title at 32px in October" do
    october = card("month")

    expect(october.fit.size).to eq(32)
    expect(lines(october.fit.notes[1])).to eq([ "This week's build log:", "Trained on me is live!! · UI", "cleanup · Landing page…" ])
  end

  it "fits September's five at 20px, the long ones cut after three lines" do
    september = card("month", offset: -1)

    expect(september.fit.size).to eq(20)
    expect(september.fit.notes.size).to eq(5)
    expect(september.fit.notes.count { |note| note.lines.size == 3 && lines(note).last.end_with?("…") }).to eq(3)
  end

  it "puts the discs on the notes' buckets, numbered in date order" do
    expect(card("year").canvas.runs.select { |run| run.face == :inter_semibold && run.size == 12 }.map(&:text).first(5))
      .to eq(%w[1 2–3 4 5 6])
  end

  it "heads the column with what the period holds and counts what did not fit" do
    year = card("year")

    expect(texts(year)).to include("10 SHIPPED", "10 PUBLISHED", "+14 more at openstage.dev/tuxnotfound")
    expect(texts(year)).to include("Jan 1 – Oct 15, so far · 380 commits on 64 days")
    expect(texts(year)).to include("+4 more")
  end

  it "says so when the period holds nothing" do
    expect(texts(card("week")).join(" ")).to include("Nothing shipped or published this week yet.")
    expect(texts(card("week"))).not_to include(a_string_matching(/SHIPPED/))
  end

  it "keeps to one project under a filter, led by its name, with no legend" do
    trained_on = card("year", repo: progress_repo(4))
    openstage = card("year", repo: progress_repo(0))

    expect([ trained_on.fit.size, trained_on.fit.notes.size ]).to eq([ 32, 1 ])
    expect(texts(trained_on)).to include("trained-on", "1 SHIPPED")
    expect(texts(openstage).join(" ")).to include("No entries tagged", "openstage in 2026 yet.")
    expect(texts(openstage)).not_to include("+4 more")
  end

  it "names several picked projects in the dateline and keeps their legend" do
    both = card("year", repo: [ progress_repo(0), progress_repo(1) ])

    expect(texts(both)).to include("openstage + wheels-off", "openstage", "176", "wheels-off", "62")
    expect(both.fills.size).to eq(2 + 2)
  end

  it "swaps an entry in for the lowest-ranked unpinned note" do
    pro_tier = progress_entry(user, 8)
    swapped = card("year", swapped: [ pro_tier.id ])

    expect(swapped.fit.notes.map { |note| note.item.id }).to include(pro_tier.id)
    expect(swapped.left_out.map(&:id)).not_to include(pro_tier.id)
  end

  it "draws in the dark palette" do
    expect(card("year", theme: "dark").palette[:bg]).to eq("#0E1012")
    expect(card("year", theme: "sepia").theme).to eq("light")
  end

  describe "with lines" do
    it "draws each project's line with the same notes, the discs on a track under the plot" do
      lines = card("year", kind: :lines)
      discs = lines.canvas.runs.select { |run| run.face == :inter_semibold && run.size == 12 }

      expect(lines.strokes.size).to eq(7)
      expect(lines.fit.notes.size).to eq(6)
      expect(discs.map(&:text).first(5)).to eq(%w[1 2–3 4 5 6])
      expect(discs.first(5).map(&:y).uniq.size).to eq(1)
      expect(lines.fills.size).to eq(3)
    end

    it "stands the discs on the one project's line, over its wash" do
      trained_on = card("year", repo: progress_repo(4), kind: :lines)

      expect(trained_on.strokes.size).to eq(1)
      expect(trained_on.wash.last).to eq("#e87ba4")
      expect(trained_on.fills).to be_empty
    end
  end
end
