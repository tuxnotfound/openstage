require "rails_helper"

RSpec.describe WeekCard, type: :model do
  let(:user) { create(:user) }
  let(:monday) { Date.new(2026, 10, 5) }
  let(:card) { described_class.new(user: user, week_start: monday) }

  describe ".week_start_for" do
    it "reads an ISO week as its Monday, and nothing else" do
      expect(described_class.week_start_for("2026-W41")).to eq(monday)
      expect(described_class.week_start_for("2026-W99")).to be_nil
      expect(described_class.week_start_for("last week")).to be_nil
      expect(described_class.param_for(monday)).to eq("2026-W41")
    end
  end

  it "only starts on a Monday" do
    card.week_start = monday + 1
    expect(card).not_to be_valid
  end

  it "shows everything until the builder turns it off" do
    card.sections = { "avatar" => "0", "streak" => "1", "made_up" => "0" }
    card.projects = { "openstage" => "0", "wheels-off" => "1" }

    expect(card.hidden_sections).to eq([ "avatar" ])
    expect(card.shows?("avatar")).to be(false)
    expect(card.shows?("streak")).to be(true)
    expect(card.shows_project?("openstage")).to be(false)
    expect(card.shows_project?("wheels-off")).to be(true)
  end

  describe "headlines" do
    it "keeps the builder's words for days of this week, trimmed to fit the card" do
      card.headlines = {
        "2026-10-06" => { "text" => "  Launched   the   blog  ", "kind" => "shipped" },
        "2026-10-07" => { "text" => "x" * 120, "kind" => "nonsense" },
        "2026-10-08" => { "text" => "   " },
        "2026-10-20" => { "text" => "Not this week" }
      }

      expect(card.headlines.keys).to eq([ "2026-10-06", "2026-10-07" ])
      expect(card.headline_on(Date.new(2026, 10, 6))).to eq("text" => "Launched the blog", "kind" => "shipped")
      expect(card.headline_on(Date.new(2026, 10, 7))).to eq("text" => "x" * 80, "kind" => "built")
    end
  end

  it "goes with the user" do
    card.save!
    user.destroy!
    expect(described_class.count).to eq(0)
  end
end
