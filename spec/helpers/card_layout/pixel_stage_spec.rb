require "rails_helper"
require "support/week_card_weeks"

# The Pixel Stage layout against its mock, doc/week_cards/mocks/pixel_stage.dc.html.
# The invented weeks are the mock's own; the texts and sizes expected are what
# its renderVals gives for them. Two of the mock's stress headlines run past
# the editor's 80 characters, so they are left out.
RSpec.describe CardLayout::PixelStage do
  include WeekCardWeeks

  let(:user) do
    create(:user, username: "tuxnotfound", display_name: "Tux", github_username: "tuxnotfound", pro: true, building_since: Date.new(2026, 3, 23))
  end

  def stage(monday, days, **choices)
    seed_week(user, monday, days)
    travel_to(monday.to_time(:utc) + 3.weeks) { described_class.new(compose_week(user, monday, days, **choices)) }
  end

  def texts(stage)
    stage.texts.map { |text| [ text.text, text.size ] }
  end

  describe "a wide week: six projects, a 60-commit day, a word wider than the callout" do
    subject(:wide) do
      stage(Date.new(2026, 10, 12), [
        { commits: { "payments-reconciliation-service" => 20, "wheels-off" => 14, "openstage" => 12, "trained-on" => 6, "story_time_v1" => 5,
                     "dotfiles" => 3 } },
        { commits: { "payments-reconciliation-service" => 8 }, kind: "built",
          words: "Supercalifragilisticexpialidocious-internationalization-refactor finally done" },
        {},
        { commits: { "payments-reconciliation-service" => 3, "wheels-off" => 8, "dotfiles" => 1 }, kind: "shipped",
          words: "payments-reconciliation-service v2.0 is live for every customer in the EU region" },
        { commits: { "trained-on" => 3, "story_time_v1" => 1 } },
        { commits: { "openstage" => 6 }, kind: "built", words: "Small fixes" },
        {}
      ], goal: "Finish onboarding and invite the first ten paying testers!!")
    end

    it "lets a block stand for two commits so the 60-commit day fits" do
      expect(texts(wide)).to include([ "1 BLOCK = 2 COMMITS", 8 ], [ "60 COMMITS", 8 ], [ "090", 24 ])
    end

    it "breaks a word wider than the callout with hyphens, at 11px" do
      expect(texts(wide)).to include([ "Supercalifragilistic-", 11 ], [ "expialidocious-", 11 ], [ "internationalizat-", 11 ],
                                     [ "ion-refactor finally", 11 ], [ "done", 11 ])
    end

    it "breaks a long repo name at its own hyphens before anything else" do
      expect(texts(wide)).to include([ "payments-", 14 ], [ "reconciliation-", 14 ], [ "service v2.0 is", 14 ], [ "EU region", 14 ])
    end

    it "names four projects in the key and counts the rest" do
      expect(texts(wide).last(9).map(&:first)).to eq([ "payments-reconciliation-service", "31", "wheels-off", "22", "openstage", "18",
                                                       "trained-on", "9", "+2 MORE" ])
    end
  end

  describe "a week with no commits and one post" do
    subject(:zero) do
      stage(Date.new(2026, 10, 19), [ {}, {}, { kind: "published", words: "Wrote up what I learned from three launches" }, {}, {}, {}, {} ],
            goal: "Get back to wheels-off")
    end

    it "sits the player by the fire, says the grass was touched six times, and keys the fires" do
      expect(zero.pose).to eq(:sit)
      expect(texts(zero)).to include([ "TOUCHED", 16 ], [ "GRASS ×6", 16 ], [ "1 FIRE = 1 DAY OFF", 8 ], [ "000", 24 ], [ "W44", 16 ])
      expect(texts(zero)).to include([ "Wrote up what", 14 ], [ "I learned from", 14 ], [ "three launches", 14 ])
    end
  end

  describe "the longest name and handle a card holds, in week 52 of a 53-week year" do
    subject(:edge) do
      user.update!(display_name: "Alexandra Konstantinopoulou", github_username: "alexandra-konstantinopoulou-builds-apps",
                   username: "alexandra-konstantinopoulou-builds-apps")
      stage(Date.new(2026, 12, 21), [ { commits: { "alpha" => 3 } } ], goal: "Rest, then plan the Q1 roadmap for every single project")
    end

    it "steps the name down and cuts it, cuts the handle before the level, and opens W53" do
      expect(texts(edge)).to include([ "ALEXANDRA KONSTANTIN…", 16 ], [ "@alexandra-konstantinopoulou-b… · LV 40", 8 ], [ "WEEK 52", 32 ], [ "W53", 16 ])
      expect(texts(edge)).to include([ "Rest, then plan the Q1 roadmap for every single project", 14 ],
                                     [ "openstage.dev/alexandra-konstantinopoulou-builds-apps", 12 ])
    end
  end

  describe "what the builder turns off" do
    let(:monday) { Date.new(2026, 10, 5) }
    let(:days) { [ {}, { commits: { "wheels-off" => 4, "openstage" => 2 }, kind: "built", words: "Arcade mode" } ] }

    before { seed_week(user, monday, days) }

    def stage_with(sections = {})
      travel_to(Time.utc(2026, 10, 20)) { described_class.new(compose_week(user, monday, days, goal: "Launch", sections: sections)) }
    end

    def strings(stage)
      stage.texts.map(&:text)
    end

    it "draws every part by default" do
      expect(strings(stage_with)).to include("TUX", "@tuxnotfound · LV 29", "COMMITS", "Arcade mode", "NEXT", "wheels-off")
      expect(stage_with.texts.find { |text| text.text == "TUX" }.x).to eq(124)
    end

    it "starts the HUD with the name without the picture, and the handle first without the name" do
      expect(stage_with({ "avatar" => "0" }).texts.find { |text| text.text == "TUX" }.x).to eq(20)
      expect(strings(stage_with({ "name" => "0" }))).to include("@tuxnotfound", "LV 29")
      expect(strings(stage_with({ "github" => "0" }))).to include("LV 29")
      expect(strings(stage_with({ "building" => "0" }))).to include("@tuxnotfound")
    end

    it "leaves out the counters, the callouts and the goal" do
      expect(strings(stage_with({ "totals" => "0" }))).not_to include("COMMITS", "006")
      expect(strings(stage_with({ "headlines" => "0" }))).not_to include("Arcade mode", "BUILT")
      expect(strings(stage_with({ "goal" => "0" }))).not_to include("NEXT", "Launch")
    end

    it "keeps each tower in its projects' colours but drops them from the key without projects" do
      bare = stage_with({ "projects" => "0" })

      expect(bare.layers.map { |_d, fill, _o| fill }).to include(*WeekCardsHelper::PROJECT_COLORS.first(2))
      expect(strings(bare)).not_to include("wheels-off")
    end
  end
end
