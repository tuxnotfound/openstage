require "rails_helper"
require "support/week_card_weeks"

# The Changelog layout against its mock, doc/week_cards/mocks/changelog.dc.html.
# The invented weeks and names below are the mock's own; the lines, sizes and
# pills expected are what its renderVals gives for them.
RSpec.describe CardLayout::Changelog do
  include WeekCardWeeks

  let(:user) { create(:user, username: "tuxnotfound", display_name: "Tux", github_username: "tuxnotfound", pro: true) }

  def layout_for(monday, days, goal: nil, posts: [], **choices)
    seed(monday, days, posts)
    layout_of(monday, days, goal: goal, **choices)
  end

  def seed(monday, days, posts)
    seed_week(user, monday, days, posts: posts)
  end

  def layout_of(monday, days, **choices)
    described_class.new(compose_week(user, monday, days, **choices))
  end

  def runs(layout, face: nil, size: nil)
    layout.canvas.runs.select { |run| (face.nil? || run.face == face) && (size.nil? || run.size == size) }
  end

  def texts(layout, **filters)
    runs(layout, **filters).map(&:text)
  end

  def words(layout)
    runs(layout).select { |run| %i[inter_medium inter_semibold].include?(run.face) && run.x == 452 }
  end

  def pills(layout)
    texts(layout, face: :dm_mono_regular, size: 11)
  end

  describe "the stress week: six projects in a day, 80-character headlines, a 36-commit day" do
    subject(:layout) do
      layout_for(Date.new(2026, 7, 27), [
        { commits: { "wheels-off" => 3, "openstage" => 2, "trained-on" => 1, "story_time_v1" => 1, "build-in-public-newsletter-archive" => 2, "cli" => 1 },
          kind: "built", words: "Split the leaderboard into four workers, so one slow write never stalls a race" },
        { commits: { "build-in-public-newsletter-archive" => 12 }, kind: "shipped",
          words: "build-in-public-newsletter-archive v1.0 goes out to everyone on the waitlist" },
        {},
        { commits: { "openstage" => 28, "wheels-off" => 8 }, kind: "built",
          words: "Rewrote the card renderer twice, and now the fonts measure the same everywhere" },
        { commits: { "cli" => 5 }, kind: "published", words: "Essay: a full year of building in public, and every mistake I made along the way" },
        { commits: { "trained-on" => 2, "cli" => 1, "wheels-off" => 1 } },
        { commits: { "story_time_v1" => 9, "openstage" => 4 }, kind: "shipped",
          words: "Story Time now reads bedtime stories aloud in three voices, and one is a dragon" }
      ], goal: "Answer every support email before lunch, every weekday")
    end

    it "steps the entries down to the size where every row fits, and balances the long ones" do
      expect(words(layout).map(&:size).uniq).to eq([ 18.5 ])
      expect(words(layout).map(&:text)).to eq([
        "Split the leaderboard into four workers, so one slow write never stalls a race",
        "build-in-public-newsletter-archive v1.0 goes out to everyone on the waitlist",
        "Rewrote the card renderer twice, and now", "the fonts measure the same everywhere",
        "Essay: a full year of building in public, and every mistake I made along the way",
        "Story Time now reads bedtime stories", "aloud in three voices, and one is a dragon"
      ])
    end

    it "folds the projects that do not fit into words, and cuts long names at a hyphen" do
      expect(pills(layout).first(5)).to eq([ "wheels-off", "build-in-public…", "openstage", "cli", "+2 projects" ])
      expect(texts(layout)).to include("4 commits across 3 projects", "Wed · no changes", "36 COMMITS")
      expect(runs(layout).find { |run| run.text.start_with?("Answer every") }.size).to eq(26)
    end
  end

  describe "a week with no commits and one post" do
    subject(:layout) do
      layout_for(Date.new(2026, 8, 24), [ {}, {}, {}, {}, { kind: "published", words: "Why I stopped coding for a week to talk to twenty users" }, {}, {} ],
                 goal: "Back to the editor on Monday", posts: [ 4 ])
    end

    it "gives the one entry the room, folds the quiet days and sets the goal large" do
      expect(words(layout).map { |run| [ run.text, run.size ] }).to eq([ [ "Why I stopped coding for a week", 42 ], [ "to talk to twenty users", 42 ] ])
      expect(texts(layout)).to include("Mon, Tue, Wed, Thu, Sat, Sun · no changes", "Outlined: a post, no commits")
      expect(runs(layout).find { |run| run.text == "Back to the editor on Monday" }.size).to eq(34)
    end
  end

  describe "seven days straight" do
    subject(:layout) do
      layout_for(Date.new(2026, 8, 17), [
        { commits: { "openstage" => 4 }, kind: "built", words: "Week card editor: pick what goes on the card" },
        { commits: { "openstage" => 6, "wheels-off" => 1 } },
        { commits: { "wheels-off" => 5 }, kind: "built", words: "Toon outlines on every car \u{1F3CE}\u{FE0F}" },
        { commits: { "wheels-off" => 2 } },
        { commits: { "openstage" => 3 }, kind: "built", words: "Dark mode for the week card" },
        { commits: { "wheels-off" => 7, "openstage" => 1 }, kind: "built", words: "Night track with real headlights" },
        { commits: { "openstage" => 2 }, kind: "published", words: "Wrote up the week on Bluesky" }
      ], goal: "Take a real day off")
    end

    it "sets a full week at 22px, counts the days without words and folds nothing" do
      expect(words(layout).map(&:size).uniq).to eq([ 22 ])
      expect(texts(layout)).to include("Toon outlines on every car", "7 commits in openstage and wheels-off", "2 commits in wheels-off")
      expect(texts(layout).grep(/no changes/)).to be_empty
    end
  end

  describe "the name and handle" do
    def identity(name, github)
      user.update!(display_name: name, github_username: github)
      layout_for(Date.new(2026, 10, 5), [ { commits: { "openstage" => 1 } } ])
    end

    it "keeps a hyphenated name on one line beside the Pro chip, a little smaller" do
      layout = identity("Jean-Baptiste Lemoine", "jblemoine")

      expect(runs(layout, face: :inter_semibold).first).to have_attributes(text: "Jean-Baptiste Lemoine", size: 17.6)
      expect(texts(layout)).to include("OPENSTAGE PRO", "@jblemoine")
    end

    it "wraps the longest name a card holds to two lines and steps the handle down" do
      layout = identity("Alexandra Konstantinopoulou-Vasquez", "alexandra-konstantinopoulou")

      expect(runs(layout, face: :inter_semibold).first(2).map { |run| [ run.text, run.size ] })
        .to eq([ [ "Alexandra", 15 ], [ "Konstantinopoulou-Vasq…", 15 ] ])
      expect(runs(layout, face: :dm_mono_regular).find { |run| run.text.start_with?("@") }).to have_attributes(text: "@alexandra-konstantinopoulou", size: 10.5)
    end
  end

  describe "what the builder turns off" do
    let(:monday) { Date.new(2026, 10, 5) }
    let(:days) do
      [ {}, { commits: { "wheels-off" => 4, "openstage" => 2 } }, { commits: { "wheels-off" => 3 }, kind: "shipped", words: "playwheelsoff.com is live" } ]
    end

    before { seed(monday, days, []) }

    def layout_with(sections = {}, layout: "week")
      layout_of(monday, days, goal: "Launch on Product Hunt", sections: sections, layout: layout)
    end

    it "draws every part by default" do
      expect(texts(layout_with)).to include("COMMITS PER DAY", "Commits", "VS W40", "UP NEXT", "@tuxnotfound", "Tux", "wheels-off",
                                            "6 commits in wheels-off and openstage", "Mon, Thu, Fri, Sat, Sun · no changes")
      expect(runs(layout_with, face: :inter_semibold).first.x).to eq(120)
    end

    it "moves the name left without the picture, and puts the handle in the name's place without the name" do
      expect(runs(layout_with({ "avatar" => "0" }), face: :inter_semibold).first.x).to eq(60)
      expect(runs(layout_with({ "name" => "0" })).find { |run| run.text == "@tuxnotfound" }.y).to eq(60)
      expect(texts(layout_with({ "name" => "0" }))).not_to include("Tux", "OPENSTAGE PRO")
      expect(texts(layout_with({ "github" => "0" }))).not_to include("@tuxnotfound")
    end

    it "leaves out the strip, the numbers, the change, the goal and the lines" do
      expect(texts(layout_with({ "activity" => "0" }))).not_to include("COMMITS PER DAY")
      expect(texts(layout_with({ "totals" => "0" }))).not_to include("Commits", "Days active")
      expect(texts(layout_with({ "compare" => "0" }))).not_to include("VS W40")
      expect(texts(layout_with({ "goal" => "0" }))).not_to include("UP NEXT", "Launch on Product Hunt")
    end

    it "counts the days without naming projects, or without the builder's words" do
      expect(pills(layout_with({ "projects" => "0" }))).to be_empty
      expect(texts(layout_with({ "projects" => "0" }))).to include("6 commits")
      expect(words(layout_with({ "headlines" => "0" }))).to be_empty
      expect(texts(layout_with({ "headlines" => "0" }))).to include("3 commits in wheels-off")
    end

    it "folds no quiet days when the builder shows only the days they worked" do
      expect(texts(layout_with(layout: "active")).grep(/no changes/)).to be_empty
    end
  end
end
