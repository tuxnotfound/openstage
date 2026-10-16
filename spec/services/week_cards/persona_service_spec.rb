require "rails_helper"

# The weeks are the Star Chart mock's (doc/week_cards/mocks/star_chart.dc.html):
# each day's commit hours and kind, and the history around the week. The
# personas expected are what the mock names them.
RSpec.describe WeekCards::PersonaService do
  let(:monday) { Date.new(2026, 10, 5) }

  # days: seven [hours, kind] pairs, Monday first.
  def persona(days, previous: nil, best: nil, quiet: 0, streak: 0, before: 1210)
    days = days.each_with_index.map { |(hours, kind), i| day(monday + i, hours, kind) }
    tally = WeekCards::TallyService::Tally.new(days: days, projects: [], totals: nil, best_run: 0, commits: [])
    history = WeekCards::HistoryService::History.new(commits_before: before, best_week: best, quiet_weeks: quiet, streak: streak,
                                                     since: nil, dust: {})
    described_class.new(tally: tally, previous: previous, history: history).tap(&:call!).persona
  end

  def day(date, hours, kind)
    kind ||= "built" if hours.any?
    headline = WeekCards::TallyService::Headline.new(text: "Words", kind: kind, project: nil, source: :builder) if kind
    WeekCards::TallyService::Day.new(date: date, label: "", segments: [], total: hours.size, headline: headline, suggestions: [],
                                     active: headline.present?, hours: hours.tally.transform_values { |n| { "app" => n } },
                                     launches: [], posts: [])
  end

  def evidence(persona)
    [ persona.evidence, persona.extra ].compact.join(" · ")
  end

  it "names a week with two launches by them, up on last week (week 41)" do
    week = [ [ [] ], [ [ 19, 20, 20, 21, 22, 23 ] ], [ [ 0, 10, 11, 12, 15, 15, 15, 16, 19, 19, 19, 20, 20, 20, 21, 23 ] ],
             [ [ 0, 1, 9, 10, 12, 13, 15, 15, 18, 19, 20 ], "shipped" ],
             [ [ 10, 11, 12, 13, 15, 15, 16, 16, 19, 19, 20, 20, 21, 22, 23, 23 ], "published" ], [ [] ],
             [ [ 0, 10, 12, 15, 15, 15, 16, 19, 19, 19, 19, 19, 20, 20, 20, 20, 20, 21, 21, 22, 22, 23, 23, 23, 23 ], "shipped" ] ]

    expect(persona(week, previous: 32, streak: 1)).to have_attributes(title: "The Serial Shipper", tagline: "You launched more than once in one week")
    expect(evidence(persona(week, previous: 32, streak: 1))).to eq("SHIPPED TWICE IN 4 DAYS · 74 COMMITS, UP FROM 32")
  end

  it "names one launch by the work before it (week 40)" do
    week = [ [ [ 9, 10, 10, 11, 11, 12, 14, 14, 15, 15, 16, 16, 17, 21, 21, 22, 22, 23 ] ], [ [ 10, 11, 20, 21, 21, 22 ] ],
             [ [ 19, 20, 20, 21, 22, 23 ] ], [ [ 11 ], "shipped" ], [ [ 9 ], "published" ], [ [] ], [ [] ] ]

    expect(persona(week, previous: 43)).to have_attributes(title: "The Launcher", tagline: "You put something out into the world")
    expect(evidence(persona(week, previous: 43))).to eq("SHIPPED THURSDAY, AFTER 30 COMMITS IN 3 DAYS")
  end

  it "falls back to the hours, with the window lit (week 38)" do
    week = [ [ [] ], [ [ 22, 23, 23 ] ], [ [] ], [ [ 10 ] ], [ [], "published" ], [ [] ], [ [] ] ]

    expect(persona(week, previous: 20)).to have_attributes(title: "The Nighthawk", evidence: "3 OF 4 COMMITS AFTER 10 PM", hours: [ 22, 28 ])
  end

  it "names a week of posts and no commits by what came before (z0)" do
    week = [ [ [] ], [ [] ], [ [], "published" ], [ [] ], [ [] ], [ [] ], [ [] ] ]

    expect(persona(week, previous: 74, best: 74, before: 1284)).to have_attributes(title: "The Storyteller")
    expect(evidence(persona(week, previous: 74, best: 74, before: 1284))).to eq("1 POST · 1,284 COMMITS SO FAR")
  end

  it "names seven days in a row, a streak that may start earlier (z6)" do
    week = [ [ [ 9, 10, 11, 20, 21 ] ], [ [ 13, 14, 14, 15, 16, 17 ] ], [ [ 19, 20, 21, 22, 23, 23 ] ],
             [ [ 10, 11, 13, 15, 16, 18, 21, 22 ], "shipped" ], [ [ 9, 10, 12, 14, 16, 18 ], "published" ], [ [ 11, 12, 15, 16 ] ],
             [ [ 9, 10, 11, 13, 14, 14, 15, 16, 20, 21 ], "shipped" ] ]

    expect(evidence(persona(week, previous: 38, streak: 7))).to eq("7 DAYS IN A ROW · 45 COMMITS, UP FROM 38")
  end

  it "names a launch week with no commits by its posts (zl)" do
    week = [ [ [] ], [ [], "shipped" ], [ [], "published" ], [ [], "published" ], [ [], "published" ], [ [] ], [ [] ] ]

    expect(persona(week, previous: 45, best: 74)).to have_attributes(title: "The Headliner",
                                                                      tagline: "You launched, then spent the week talking about it")
    expect(evidence(persona(week, previous: 45, best: 74))).to eq("SHIPPED TUESDAY · THEN 3 POSTS")
  end

  it "names commits after two quiet weeks (zc)" do
    week = [ [ [] ], [ [ 20, 21, 21, 22, 23, 23 ] ], [ [ 10, 11, 13, 14, 15, 16, 21, 22, 22 ] ], [ [] ], [ [ 19, 20, 20, 21, 23 ] ],
             [ [ 9, 10, 10 ], "published" ], [ [] ] ]

    expect(evidence(persona(week, previous: 0, best: 74, quiet: 2))).to eq("BACK AFTER TWO QUIET WEEKS · 23 COMMITS IN 4 DAYS")
  end

  it "names a record week first (zr)" do
    week = [ [ Array.new(17, 12) ], [ Array.new(16, 12) ], [ Array.new(15, 12) ], [ Array.new(20, 12), "shipped" ], [ Array.new(17, 12) ],
             [ Array.new(11, 12), "published" ], [ [] ] ]

    expect(persona(week, previous: 23, best: 74)).to have_attributes(title: "The Record Breaker", tagline: "Your most commits in a single week",
                                                                      evidence: "96 COMMITS, THE OLD BEST WAS 74")
  end

  describe "the hours" do
    def at(*hours)
      [ [ hours ] ] + Array.new(6) { [ [] ] }
    end

    it "reads after dark, early and the working day" do
      expect(persona(at(19, 20, 21, 12))).to have_attributes(title: "The Night Owl", evidence: "3 OF 4 COMMITS BETWEEN 7 PM AND 4 AM", hours: [ 19, 28 ])
      expect(persona(at(5, 6, 7, 12, 13, 14, 15, 16, 19, 20))).to have_attributes(title: "The Early Bird", hours: [ 4, 9 ])
      expect(persona(at(9, 10, 11, 12, 20))).to have_attributes(title: "The Daylighter", evidence: "4 OF 5 COMMITS BETWEEN 9 AM AND 6 PM")
    end

    it "splits the rest into a double shift" do
      expect(persona(at(10, 11, 18, 19, 20))).to have_attributes(title: "The Double Shift", evidence: "3 COMMITS BY DAY · 2 AFTER 7 PM")
    end

    it "says one or both commits in words" do
      expect(persona(at(23)).evidence).to eq("YOUR ONE COMMIT LANDED AFTER 10 PM")
      expect(persona(at(22, 23)).evidence).to eq("BOTH COMMITS LANDED AFTER 10 PM")
      expect(persona(at(20, 21)).evidence).to eq("BOTH COMMITS LANDED BETWEEN 7 PM AND 4 AM")
    end
  end

  it "names a week with nothing in it" do
    expect(persona(Array.new(7) { [ [] ] }, before: 0)).to have_attributes(title: "The Stargazer", evidence: "A CLEAR SKY", extra: "0 COMMITS SO FAR")
  end

  it "needs the week and its history" do
    expect(described_class.new(tally: nil, history: nil).call).to be(false)
  end
end
