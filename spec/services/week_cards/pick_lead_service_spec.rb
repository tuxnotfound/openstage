require "rails_helper"

RSpec.describe WeekCards::PickLeadService do
  let(:monday) { Date.new(2026, 10, 5) }
  let(:week_card) { WeekCard.new(user: build(:user), week_start: monday) }
  let(:tally_types) { WeekCards::TallyService }

  # One day of the week: its commits per project and the headline it got.
  def day(offset, commits = {}, text: nil, kind: "built", source: :builder)
    segments = commits.map { |name, n| tally_types::Segment.new(project: name, n: n, slot: 0) }
    headline = text && tally_types::Headline.new(text: text, kind: kind, project: nil, source: source)
    tally_types::Day.new(date: monday + offset, label: "", segments: segments, total: commits.values.sum,
                         headline: headline, suggestions: [], active: commits.any? || headline.present?)
  end

  def lead(*days)
    totals = tally_types::Totals.new(commits: days.sum(&:total), active_days: days.count(&:active), projects: 0, shipped: 0, published: 0)
    projects = days.flat_map(&:segments).group_by(&:project)
                   .map { |name, segments| tally_types::Project.new(name: name, n: segments.sum(&:n), slot: 0, shown: true) }
                   .sort_by { |project| -project.n }
    tally = tally_types::Tally.new(days: days, projects: projects, totals: totals, best_run: 0, commits: [])
    described_class.new(week_card: week_card, tally: tally).tap(&:call!).lead
  end

  let(:week) do
    [ day(1, { "wheels-off" => 4, "openstage" => 2 }, text: "6 commits in wheels-off and openstage", source: :count),
      day(2, { "wheels-off" => 16 }, text: "Arcade mode: leaderboards, world record, name entry"),
      day(3, { "wheels-off" => 11 }, text: "playwheelsoff.com is live", kind: "shipped"),
      day(4, { "openstage" => 11, "trained-on" => 5 }, text: "Posted on X", kind: "published", source: :entry),
      day(6, { "openstage" => 21, "wheels-off" => 4 }, text: "Read-only private repos via a GitHub App", kind: "shipped") ]
  end

  it "leads with the builder's launch on the busiest day, said in plain words" do
    expect(lead(*week)).to have_attributes(date: monday + 6, text: "Read-only private repos via a GitHub App",
                                           fly: "Shipped on Sunday, Oct 11", generated: false)
  end

  it "leads with the day the builder picked" do
    week_card.lead_on = monday + 3

    expect(lead(*week)).to have_attributes(text: "playwheelsoff.com is live", fly: "Shipped on Thursday, Oct 8")
  end

  it "gives a picked count line the date alone" do
    week_card.lead_on = monday + 1

    expect(lead(*week)).to have_attributes(text: "6 commits in wheels-off and openstage", fly: "Tuesday, Oct 6", generated: true)
  end

  it "keeps the rule when the picked day has nothing to say" do
    week_card.lead_on = monday

    expect(lead(*week).date).to eq(monday + 6)
  end

  it "takes the builder's words over a launch the card found by itself" do
    built = day(1, { "app" => 3 }, text: "Story Time exports to PDF")
    release = day(2, { "app" => 9 }, text: "story-time v1.0", kind: "shipped", source: :entry)

    expect(lead(built, release)).to have_attributes(text: "Story Time exports to PDF", fly: "Built on Tuesday, Oct 6")
  end

  it "takes a busier built day over a post, and a post in the builder's words over the numbers" do
    post = day(4, text: "Why I stopped coding for a week", kind: "published")

    expect(lead(day(1, { "app" => 2 }, text: "Ghost car replays"), post).text).to eq("Ghost car replays")
    expect(lead(day(1, { "app" => 2 }, text: "2 commits in app", source: :count), post))
      .to have_attributes(text: "Why I stopped coding for a week", fly: "Published on Friday, Oct 9")
  end

  it "leads with a launch the card found when the builder wrote nothing" do
    release = day(2, { "wheels-off" => 3 }, text: "wheels-off v1.0", kind: "shipped", source: :entry)

    expect(lead(release, day(4, { "app" => 9 }, text: "9 commits in app", source: :count)).text).to eq("wheels-off v1.0")
  end

  it "leads with the week's numbers rather than a line the card wrote" do
    counts = [ day(1, { "wheels-off" => 35 }, text: "35 commits in wheels-off", source: :count),
               day(4, { "openstage" => 34, "trained-on" => 5 }, text: "Posted on X", kind: "published", source: :entry) ]

    expect(lead(*counts)).to have_attributes(date: nil, text: "74 commits in 3 projects", fly: "Built this week")
  end

  it "leads a week without commits with its post, and an empty week quietly" do
    expect(lead(day(4, text: "Posted on X", kind: "published", source: :entry)).fly).to eq("Published on Friday, Oct 9")
    expect(lead(day(0))).to have_attributes(text: "A quiet week", fly: "Week 41")
  end

  it "says what a launch was when its words were only emoji" do
    expect(lead(day(3, { "app" => 1 }, text: "\u{1F680}\u{1F525}", kind: "shipped"))).to have_attributes(text: "Shipped", fly: "Thursday, Oct 8")
  end

  it "leads with the numbers when the card hides headlines" do
    week_card.sections = { "headlines" => "0" }

    expect(lead(*week).text).to eq("74 commits in 3 projects")
  end

  it "needs the week's tally" do
    expect(described_class.new(week_card: week_card, tally: nil).call).to be(false)
  end
end
