require "rails_helper"

RSpec.describe WeekCardsHelper, type: :helper do
  let(:font) { { size: 13, weight: 600 } }

  describe "#card_wrap" do
    it "breaks between words so each line fits the width" do
      lines = helper.card_wrap("Serve the game at playwheelsoff.com, workers.dev off", 148, max_lines: 4, **font)

      expect(lines.join(" ")).to eq("Serve the game at playwheelsoff.com, workers.dev off")
      expect(lines.map { |line| CardText.width(line, **font) }).to all(be <= 148)
    end

    it "ends a headline that runs over with an ellipsis" do
      lines = helper.card_wrap("one two three four five six seven eight nine ten", 60, max_lines: 2, **font)

      expect(lines.size).to eq(2)
      expect(lines.last).to end_with("…")
      expect(CardText.width(lines.last, **font)).to be <= 60
    end

    it "cuts a single word wider than the line" do
      expect(CardText.width(helper.card_wrap("x" * 60, 80, max_lines: 3, **font).first, **font)).to be <= 80
    end
  end

  describe "#card_delta" do
    it "says how a number moved, as a percentage or a difference" do
      expect(helper.card_delta(74, 32, percent: true)).to eq([ "↑ 131%", :up ])
      expect(helper.card_delta(2, 4)).to eq([ "↓ 2", :down ])
    end

    it "says nothing without a change or anything to compare with" do
      expect(helper.card_delta(3, 3)).to be_nil
      expect(helper.card_delta(3, nil)).to be_nil
      expect(helper.card_delta(3, 0, percent: true)).to be_nil
    end
  end

  describe "#card_cells" do
    let(:user) { create(:user) }
    let(:week_card) { WeekCard.new(user: user, week_start: Date.new(2026, 10, 5), hidden_sections: []) }
    let(:extras) do
      WeekCards::ExtrasService::Extras.new(building: nil, audience: nil, hours: WeekCards::ExtrasService::Hours.new(counts: [ 1 ] * 24, peak_from: 0, peak_to: 2),
                                           code: nil, repos: WeekCards::ExtrasService::Repos.new(merged_prs: 0, releases: 1, deploys: 0, stars: 0))
    end

    def cells
      helper.card_cells(Struct.new(:week_card, :extras).new(week_card, extras))
    end

    it "shows only the cells the builder kept on that have something to say, across the full width" do
      week_card.next_goal = "Launch"

      expect(cells.map { |cell| cell[:kind] }).to eq(%i[goal hours repos])
      expect(cells.first[:x]).to eq(26)
      expect(cells.last[:x] + cells.last[:width]).to be_within(1).of(1174)
    end

    it "leaves out a cell the builder turned off" do
      week_card.sections = { "hours" => "0" }

      expect(cells.map { |cell| cell[:kind] }).to eq(%i[repos])
    end
  end

  describe "#card_legend" do
    it "keeps the busiest projects that fit, ending on the strip's right edge" do
      project = WeekCards::TallyService::Project
      projects = [ project.new(name: "wheels-off", n: 35, slot: 0, shown: true), project.new(name: "openstage", n: 34, slot: 1, shown: true),
                   project.new(name: "hidden", n: 9, slot: nil, shown: false) ]

      items = helper.card_legend(projects, after: 400)
      expect(items.map { |item| item[:name] }).to eq(%w[wheels-off openstage])
      expect(items.last[:x] + items.last[:width]).to be_within(1).of(1158)
      expect(helper.card_legend(projects, after: 1100)).to be_empty
    end
  end
end
