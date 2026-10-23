require "rails_helper"

RSpec.describe CardLayout::Progress do
  let(:user) { create(:user, display_name: "Mia Maker", username: "mia") }

  before { travel_to Time.utc(2026, 10, 15, 12) }

  def card(swapped_ids: nil, theme: "light")
    section = Progress::ComposeService.new(user: user, range: "90d", rolling: true, swapped_ids: swapped_ids).tap(&:call!).section
    described_class.new(section, user: user, theme: theme)
  end

  def milestone(title, days_ago)
    create(:entry, user: user, entry_type: "milestone", source: "manual", title: title, repo_name: "mia/app", occurred_at: days_ago.days.ago)
  end

  before { create(:entry, user: user, repo_name: "mia/app", occurred_at: 3.days.ago) }

  it "numbers every pick beside the chart when they fit, with a disc for each on the chart" do
    3.times { |i| milestone("Short #{i}", (i + 1) * 10) }

    layout = card
    expect(layout.notes.map { |note| note.lines.join(" ") }).to eq([ "Short 2", "Short 1", "Short 0" ])
    expect(layout.discs.size).to eq(3)
    expect(layout.left_out).to be_empty
  end

  it "keeps fewer when long titles crowd the column, and the latest swap stays" do
    long = "A long title about a launch that keeps going well past the width of the column it is set in, and then some more" * 2
    items = 8.times.map { |i| milestone("#{long} #{i}", (i + 1) * 9) }

    crowded = card
    expect(crowded.notes.size).to be < 6
    expect(crowded.notes.map(&:lines)).to all(satisfy { |lines| lines.size == 2 && lines.last.end_with?("…") })
    expect(crowded.discs.size).to eq(crowded.notes.size)

    left = crowded.left_out.first
    expect(card(swapped_ids: [ left.id ]).notes.map(&:item)).to include(left)
    expect(items).to include(left.entry)
  end

  it "draws on the dark ground when asked, and on the light one for anything else" do
    expect([ card(theme: "dark").palette[:bg], card(theme: "sepia").palette[:bg] ]).to eq(%w[#0E0F12 #FFFFFF])
  end
end
