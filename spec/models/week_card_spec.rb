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

  it "starts with audience off, since small numbers can work against a builder" do
    expect(card.shows?("audience")).to be(false)
    expect(card.shows?("hours")).to be(true)
  end

  it "leads only with a day of its own week, or by its own rule" do
    card.lead_on = monday + 3
    expect(card).to be_valid

    card.lead_on = monday + 7
    expect(card).not_to be_valid

    card.lead_on = ""
    expect(card.lead_on).to be_nil
  end

  it "is light or dark" do
    card.theme = "neon"
    expect(card).not_to be_valid
  end

  it "keeps next week's goal short and tidy" do
    card.next_goal = "  Launch   on Product Hunt #{'!' * 80}"
    expect(card.next_goal).to start_with("Launch on Product Hunt")
    expect(card.next_goal.length).to eq(WeekCard::GOAL_LENGTH)

    card.next_goal = "   "
    expect(card.next_goal).to be_nil
  end

  describe "time zone" do
    it "runs the week from Monday to Monday in the card's zone" do
      card.time_zone = "Asia/Tokyo"

      expect(card.time_range.begin).to eq(Time.utc(2026, 10, 4, 15))
      expect(card.time_range.end).to eq(Time.utc(2026, 10, 11, 15))
    end

    it "falls back to UTC for a zone Rails does not know" do
      card.time_zone = "Mars/Olympus"

      expect(card.time_zone).to be_nil
      expect(card.zone.name).to eq("UTC")
    end

    it "remembers the builder's last zone for the next card" do
      described_class.create!(user: user, week_start: monday - 7, time_zone: "Europe/Lisbon")
      described_class.create!(user: create(:user), week_start: monday, time_zone: "Asia/Tokyo")

      expect(described_class.last_time_zone_for(user)).to eq("Europe/Lisbon")
    end
  end

  it "goes with the user" do
    card.save!
    user.destroy!
    expect(described_class.count).to eq(0)
  end
end
