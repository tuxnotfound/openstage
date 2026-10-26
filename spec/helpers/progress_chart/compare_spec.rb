require "rails_helper"

RSpec.describe ProgressChart::Compare do
  let(:user) { create(:user, username: "builder") }

  # Wednesday: the 90-day view has two weeks, from the first commit's.
  before do
    travel_to Time.utc(2026, 10, 28, 12)
    3.times { create(:entry, user: user, repo_name: "builder/app", occurred_at: Time.utc(2026, 10, 19, 12)) }
    create(:entry, user: user, repo_name: "builder/app", occurred_at: Time.utc(2026, 10, 27, 12))
  end

  def chart(visits)
    section = Progress::ComposeService.new(user: user, range: "90d", rolling: true).tap(&:call!).section
    described_class.new(ProgressChart::Trend.new(section), visits: { "builder/app" => visits }, projects: section.tally.projects)
  end

  it "draws commits solid and visits dotted, each number against its own peak, with the real numbers in the tooltip" do
    compare = chart([ 0, 400 ])

    expect(compare.lines.map { |line| [ line.key, line.dashed? ] }).to eq([ [ "builder/app|commits", false ], [ "builder/app|visits", true ] ])
    expect(compare.paths.map { |path| path[2] }).to eq([ true, false ])
    expect(compare.ticks.map(&:value)).to eq(%w[50% 100%])
    expect(compare.columns.last.rows.map { |row| [ row.name, row.value ] }).to eq([ [ "app · commits", 1 ], [ "app · site visits", 400 ] ])
  end

  it "reaches the same height for each number's peak, whatever its scale" do
    peaks = chart([ 0, 400 ]).paths.map { |d, *| d.scan(/[ML][\d.]+ ([\d.]+)/).flatten.map(&:to_f).min }

    expect(peaks.uniq.size).to eq(1)
  end

  it "keeps a number's projects on one scale, so they still compare" do
    create(:entry, user: user, repo_name: "builder/lib", occurred_at: Time.utc(2026, 10, 27, 12))
    tops = chart([ 0, 400 ]).paths.reject { |path| path[2] }.map { |d, *| d.scan(/[ML][\d.]+ ([\d.]+)/).flatten.map(&:to_f).min }

    expect(tops.uniq.size).to eq(2)
  end

  it "leaves out a project with no visits in the window, and draws commits alone on their own axis" do
    compare = chart([ 0, 0 ])

    expect(compare.lines.map(&:key)).to eq([ "builder/app|commits" ])
    expect(compare.ticks.map(&:value)).not_to include("100%")
  end

  it "leaves out the lines switched off" do
    section = Progress::ComposeService.new(user: user, range: "90d", rolling: true).tap(&:call!).section
    compare = described_class.new(ProgressChart::Trend.new(section), visits: { "builder/app" => [ 0, 400 ] }, projects: section.tally.projects,
                                                                     hidden: { "builder/app" => [ "commits" ] })

    expect(compare.lines.map(&:key)).to eq([ "builder/app|visits" ])
    expect(compare.aria_label).to eq("Site visits per week by project, last 90 days")
  end
end
