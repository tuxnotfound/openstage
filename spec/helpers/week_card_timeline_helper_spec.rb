require "rails_helper"

RSpec.describe WeekCardTimelineHelper, type: :helper do
  let(:segment) { WeekCards::TallyService::Segment }
  let(:day) do
    Struct.new(:total, :segments).new(16, [ segment.new(project: "openstage", n: 11, slot: 0), segment.new(project: "trained-on", n: 5, slot: 1) ])
  end

  before { helper.extend(WeekCardsHelper) }

  describe "#card_columns" do
    it "gives each day an equal column, bars up and down in turn" do
      columns = helper.card_columns(%w[mon tue wed thu fri])

      expect(columns.map { |col| col[:width].round(1) }.uniq).to eq([ 224.0 ])
      expect(columns.map { |col| col[:up] }).to eq([ true, false, true, false, true ])
      expect(columns.first[:cx]).to eq(152)
    end
  end

  it "never lets one commit stand taller than sixteen pixels" do
    days = [ Struct.new(:total).new(2), Struct.new(:total).new(1) ]
    expect(helper.card_bar_scale(days, 130)).to eq(16)
  end

  describe "#card_bar" do
    it "grows from the line, busiest project nearest it" do
      up = helper.card_bar(day, 5, line: 300, up: true, merged: false)
      down = helper.card_bar(day, 5, line: 300, up: false, merged: false)

      expect(up.map { |block| [ block[:y], block[:height] ] }).to eq([ [ 244, 55 ], [ 217, 25 ] ])
      expect(down.map { |block| [ block[:y], block[:height] ] }).to eq([ [ 301, 55 ], [ 358, 25 ] ])
    end

    it "is one block for the day when the card hides projects" do
      expect(helper.card_bar(day, 5, line: 300, up: true, merged: true).map { |block| block[:height] }).to eq([ 80 ])
    end
  end

  describe "#card_headline_size" do
    it "shrinks the type until the longest word fits" do
      expect(helper.card_headline_size("playwheelsoff.com is live", 120, base: 15, weight: 700)).to be < 15
      expect(helper.card_headline_size("Ship it", 120, base: 15, weight: 700)).to eq(15)
    end
  end

  describe "#card_day_words" do
    let(:headline) { WeekCards::TallyService::Headline.new(text: "Read-only private repos via a GitHub App", kind: "shipped", project: nil, source: :builder) }

    it "keeps every line and chip inside the day's column" do
      words = helper.card_day_words(day, headline, width: 148, merged: false)
      lines = words[:rows].select { |row| row[:line] }
      chips = words[:rows].flat_map { |row| row[:chips].to_a }

      expect(words[:rows].first[:kind]).to eq("SHIPPED")
      expect(lines.map { |row| CardText.width(row[:line], size: row[:size], weight: 700) }).to all(be <= 148)
      expect(chips.map { |chip| [ chip[:x], chip[:x] + chip[:width] ] }.flatten.map(&:abs)).to all(be <= 74)
    end

    it "puts chips side by side when they fit, and leaves them out when projects are hidden" do
      wide = helper.card_day_words(day, headline, width: 300, merged: false)
      merged = helper.card_day_words(day, headline, width: 300, merged: true)

      expect(wide[:rows].count { |row| row[:chips] }).to eq(1)
      expect(merged[:rows].count { |row| row[:chips] }).to eq(0)
      expect(merged[:height]).to be < wide[:height]
    end
  end

  it "reads amber in a deeper shade on the light card" do
    expect(helper.card_project_ink(2, "light")).to eq("#B7791F")
    expect(helper.card_project_ink(2, "dark")).to eq("#FFB020")
    expect(helper.card_project_ink(nil, "light")).to be_nil
  end
end
