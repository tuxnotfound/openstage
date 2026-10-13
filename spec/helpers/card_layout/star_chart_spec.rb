require "rails_helper"
require "support/week_card_weeks"

# The Star Chart layout against its mock, doc/week_cards/mocks/star_chart.dc.html.
# The invented weeks are the mock's own; the lines, sizes and splits expected
# are what its renderVals gives for them.
RSpec.describe CardLayout::StarChart do
  include WeekCardWeeks

  let(:user) { create(:user, username: "tuxnotfound", display_name: "Tux", github_username: "tuxnotfound", pro: true) }

  def chart(monday, days, posts: [], **choices)
    seed_week(user, monday, days, posts: posts)
    travel_to(monday.to_time(:utc) + 3.weeks) { described_class.new(compose_week(user, monday, days, **choices)) }
  end

  def runs(chart, face: nil)
    chart.canvas.runs.select { |run| face.nil? || run.face == face }
  end

  def texts(chart)
    runs(chart).map(&:text)
  end

  # The days' words, set after the gutter and the glyph.
  def words(chart)
    runs(chart, face: :dm_sans_medium).select { |run| run.x == 134 }
  end

  describe "a full week: six projects, long names, 80-character headlines, seven days in a row" do
    subject(:star_chart) do
      user.update!(display_name: "Bartholomew Pennington", github_username: "bartholomew-pennington")
      chart(Date.new(2026, 10, 19), [
        { commits: { "a-very-long-project-name-for-testing" => 3, "openstage" => 2 }, hours: [ 9, 10, 11, 20, 21 ], kind: "built",
          words: "Rebuilt onboarding so a new builder sees their own page within the first minute" },
        { commits: { "invoice-reconciliation-service" => 6 }, hours: [ 13, 14, 14, 15, 16, 17 ], kind: "built",
          words: "Reconciliation handles partial refunds, multi-currency invoices and late fees" },
        { commits: { "story_time_v1" => 4, "trained-on" => 2 }, hours: [ 19, 20, 21, 22, 23, 23 ], kind: "built",
          words: "Story Time reads aloud now: a narrator voice, page turns and a bedtime timer" },
        { commits: { "wheels-off" => 8 }, hours: [ 10, 11, 13, 15, 16, 18, 21, 22 ], kind: "shipped",
          words: "Wheels-off 1.0 is out with ghost racing, weekly leaderboards and a photo mode" },
        { commits: { "openstage" => 5, "invoice-reconciliation-service" => 1 }, hours: [ 9, 10, 12, 14, 16, 18 ], kind: "published",
          words: "Posted a long thread on X about pricing experiments that did not work at all" },
        { commits: { "trained-on" => 3, "invoice-reconciliation-service" => 1 }, hours: [ 11, 12, 15, 16 ], kind: "built",
          words: "Internationalization-pipeline rebuilt for twelve locales" },
        { commits: { "a-very-long-project-name-for-testing" => 6, "story_time_v1" => 4 }, hours: [ 9, 10, 11, 13, 14, 14, 15, 16, 20, 21 ],
          kind: "shipped", words: "Shipped the long-awaited dark mode across every single page of the app today" }
      ], goal: "Raise prices, then write a changelog entry for every change")
    end

    it "names the week by its run of days" do
      expect(runs(star_chart, face: :newsreader_title).first.text).to eq("The Marathoner")
      expect(texts(star_chart)).to include("7 DAYS IN A ROW · 45 COMMITS")
    end

    it "sets the rows at 14px with the counts closing each last line, wrapping like the mock" do
      expect(words(star_chart).map(&:size).uniq).to eq([ 14 ])
      expect(words(star_chart).map(&:text)).to eq([
        "Rebuilt onboarding so a new builder sees their", "own page within the first minute",
        "Reconciliation handles partial refunds,", "multi-currency invoices and late fees",
        "Story Time reads aloud now: a narrator voice,", "page turns and a bedtime timer",
        "Wheels-off 1.0 is out with ghost racing,", "weekly leaderboards and a photo mode",
        "Posted a long thread on X about pricing", "experiments that did not work at all",
        "Internationalization-pipeline rebuilt for twelve locales",
        "Shipped the long-awaited dark mode across", "every single page of the app today"
      ])
    end

    it "splits the legend over two lines, the biggest projects on the first" do
      names = runs(star_chart, face: :dm_sans_regular).select { |run| run.size == 12.5 }.group_by(&:y).values.map { |line| line.map(&:text) }

      expect(names).to eq([ %w[a-very-long-project-name-for-testing story_time_v1],
                            %w[invoice-reconciliation-service wheels-off openstage trained-on] ])
    end

    it "keeps the long name and handle whole beside Pro, and wraps the goal" do
      expect(runs(star_chart, face: :dm_sans_bold).first).to have_attributes(text: "Bartholomew Pennington", size: 19)
      expect(texts(star_chart)).to include("@bartholomew-pennington", "PRO", "Raise prices, then write a", "changelog entry for every change")
    end
  end

  describe "a week with one post and no commits" do
    subject(:star_chart) do
      chart(Date.new(2026, 10, 12), [ {}, {}, { kind: "published", words: "Wrote the launch plan and posted it on X" }, {}, {}, {}, {} ],
            posts: [ [ 2, 21 ] ])
    end

    it "keeps every quiet day as a slim row, gives the one entry the room, and draws its comet" do
      expect(words(star_chart).map { |run| [ run.text, run.size ] }).to eq([ [ "Wrote the launch plan and posted it on X", 22 ] ])
      expect(texts(star_chart).count("quiet")).to eq(6)
      expect(star_chart.stars.comets.size).to eq(1)
      expect(runs(star_chart, face: :newsreader_title).first.text).to eq("The Storyteller")
    end
  end

  describe "what the builder turns off" do
    let(:monday) { Date.new(2026, 10, 5) }
    let(:days) { [ {}, { commits: { "wheels-off" => 4, "openstage" => 2 }, hours: [ 22, 22, 23, 23, 21, 22 ] } ] }

    before { seed_week(user, monday, days) }

    def chart_with(sections = {}, layout: "week")
      travel_to(Time.utc(2026, 10, 20)) do
        described_class.new(compose_week(user, monday, days, goal: "Launch on Product Hunt", sections: sections, layout: layout))
      end
    end

    it "draws every part by default, the hour window lit" do
      expect(texts(chart_with)).to include("Tux", "@tuxnotfound", "PRO", "The Nighthawk", "COMMITS", "NEXT", "wheels-off", "quiet")
      expect(chart_with.sky.arc).to be_present
      expect(chart_with.avatar).to be_present
    end

    it "names the week by its number without the persona, and lights no window" do
      expect(runs(chart_with({ "persona" => "0" }), face: :newsreader_title).first.text).to eq("Week 41")
      expect(texts(chart_with({ "persona" => "0" }))).not_to include("Most of your building happens after 10 PM")
      expect(chart_with({ "persona" => "0" }).sky.arc).to be_nil
    end

    it "puts a gold star in the centre without the picture, and the handle first without the name" do
      expect(chart_with({ "avatar" => "0" }).avatar).to be_nil
      expect(runs(chart_with({ "name" => "0" })).find { |run| run.text == "@tuxnotfound" }.x).to eq(48)
      expect(texts(chart_with({ "github" => "0" }))).not_to include("@tuxnotfound")
    end

    it "turns the stars to one ink and drops the legend and counts without projects" do
      bare = chart_with({ "projects" => "0" })

      expect(bare.hues).to be_empty
      expect(bare.legend.dots).to be_empty
      expect(texts(bare)).to include("6 commits")
    end

    it "leaves out the total, the goal, the dust and the quiet days" do
      expect(texts(chart_with({ "totals" => "0" }))).not_to include("COMMITS")
      expect(texts(chart_with({ "goal" => "0" }))).not_to include("NEXT")
      expect(chart_with({ "history" => "0" }).stars.dust).to be_empty
      expect(texts(chart_with(layout: "active"))).not_to include("quiet")
    end

    it "writes count lines only without the builder's words" do
      expect(words(chart_with({ "headlines" => "0" })).map(&:text)).to eq([ "6 commits in 2 projects" ])
    end
  end
end
