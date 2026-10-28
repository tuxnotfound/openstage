require "rails_helper"

RSpec.describe ProgressChart::Compare do
  let(:commits) { Progress::Numbers.find("commits") }
  let(:visits) { Progress::Numbers.find("visits") }

  # Wednesday Oct 28; the work began on Monday Oct 19, so the 90-day view
  # has two weekly points and the 30-day view ten days.
  def window(range = "90d")
    Progress::Window.new(range: range, today: Date.new(2026, 10, 28), first_activity: Date.new(2026, 10, 19))
  end

  def line(repo, number, values, rank: 0)
    described_class::Line.new(repo: "builder/#{repo}", name: repo, rank: rank, color_class: "os-project-#{rank + 1}", number: number, values: values,
                              total: values.sum)
  end

  def chart(lines, numbers: [ commits, visits ], range: "90d", **options)
    described_class.new(window: window(range), lines: lines, numbers: numbers, **options)
  end

  def tops(paths)
    paths.map { |d, *| d.scan(/[ML][\d.]+ ([\d.]+)/).flatten.map(&:to_f).min }
  end

  it "draws a line per project and number, each carrying its colour and its number, every number against its own peak" do
    compare = chart([ line("app", commits, [ 3, 1 ]), line("app", visits, [ 0, 400 ]) ])

    expect(compare.paths.map { |path| path.drop(1) }).to eq([ [ "os-project-1", "visits", "builder/app" ], [ "os-project-1", "commits", "builder/app" ] ])
    expect(compare.ticks.map(&:value)).to eq(%w[50% 100%])
    expect(tops(compare.paths).uniq.size).to eq(1)
  end

  it "keeps a number's projects on one scale, so they still compare" do
    compare = chart([ line("app", commits, [ 3, 1 ]), line("lib", commits, [ 0, 1 ], rank: 1), line("app", visits, [ 0, 400 ]) ])

    expect(tops(compare.paths.select { |path| path[2] == "commits" }).uniq.size).to eq(2)
  end

  it "keeps the real numbers in the tooltip, a row per project and a column per number, a dash where a project counts none" do
    compare = chart([ line("app", commits, [ 3, 1 ]), line("app", visits, [ 0, 1400 ]), line("lib", commits, [ 0, 2 ], rank: 1) ])

    expect(compare.lined.map(&:key)).to eq(%w[commits visits])
    expect(compare.columns.last.rows.map { |row| [ row.name, row.values ] }).to eq([ [ "app", %w[1 1,400] ], [ "lib", %w[2 –] ] ])
    expect(compare.columns.first.rows.map(&:name)).to eq([ "app" ])
    expect(compare.columns.first.title).to eq("Week of Oct 19–25")
  end

  it "names each line style by the numbers' places among those drawn, and gives each number's peak" do
    compare = chart([ line("app", commits, [ 3, 1 ]), line("app", visits, [ 0, 400 ]) ], numbers: [ visits, commits ])

    after = ", each against its own peak in the window; 100% is 3 commits a week and 400 site visits a week."
    expect(compare.note).to eq("Commits dotted and site visits solid#{after}")
    expect(compare.note_parts).to eq([ "", after ])
    expect(compare.aria_label).to eq("Commits and site visits per week by project, each against its own peak, last 90 days")
  end

  it "draws one number on its own axis, and says which numbers drawn have no line, and why" do
    quiet = chart([ line("app", commits, [ 3, 1 ]), line("app", visits, [ 0, 0 ]) ])
    expect(quiet.indexed?).to be(false)
    expect(quiet.ticks.map(&:value)).to eq(%w[2 4])
    expect(quiet.note).to eq("Commits per week, one line per project. No site visits in the last 90 days.")
    expect(quiet.note_parts).to be_nil

    missing = chart([ line("app", commits, [ 3, 1 ]) ], lone: true)
    expect(missing.note).to eq("Commits per week. None of the projects in view counts site visits.")
  end

  it "gives a peak of one in the singular" do
    compare = chart([ line("app", commits, [ 1, 0 ]), line("app", visits, [ 0, 400 ]) ])

    expect(compare.note).to end_with("100% is 1 commit a week and 400 site visits a week.")
  end

  it "averages the 30-day view to a tenth, its tooltip saying so" do
    compare = chart([ line("app", commits, [ 0, 0, 0, 0, 0, 0, 0, 0, 0.5, 1.5 ]) ], numbers: [ commits ], range: "30d", average: true)

    expect(compare.note).to eq("A 7-day average of commits per day, one line per project.")
    expect(compare.aria_label).to eq("7-day average of commits per day by project, last 30 days")
    expect(compare.ticks.map(&:value)).to eq([ "0.5", "1", "1.5" ])
    expect(compare.columns.last).to have_attributes(title: "Wed, Oct 28 · 7-day average")
    expect(compare.columns.last.rows.sole.values).to eq([ "1.5" ])
  end

  it "words a chart of pages by page, as analytics draws it, the builder's own page first in the tooltip" do
    views = Progress::Numbers.find("views")
    own = described_class::Line.new(repo: "page", name: "Your page", rank: nil, color_class: "os-project-none", number: views, values: [ 0, 5 ], total: 5)
    expect(chart([ line("app", views, [ 0, 2 ]), own ], numbers: [ views ], per: "page").columns.last.rows.map(&:name)).to eq([ "Your page", "app" ])

    compare = chart([ line("app", commits, [ 3, 1 ]) ], per: "page")

    expect(compare.note).to eq("Commits per week, one line per page. None of the pages in view counts site visits.")
    expect(compare.aria_label).to eq("Commits per week by page, last 90 days")
    expect(chart([], numbers: [], per: "page").note).to eq("No page here shows a number yet.")
  end

  it "says when nothing is drawn, or nothing is in the window" do
    expect(chart([], numbers: []).note).to eq("No project here shows a number yet.")
    expect(chart([ line("app", commits, [ 0, 0 ]) ], numbers: [ commits ]).note).to eq("No commits in the last 90 days.")
    expect(chart([ line("app", commits, [ 0, 0 ]) ], numbers: [ commits ]).paths).to be_empty
  end

  it "draws no gridlines without a line, so an empty chart suggests no scale" do
    expect(chart([ line("app", commits, [ 0, 0 ]) ], numbers: [ commits ]).ticks).to be_empty
    expect(chart([], numbers: [ visits ], range: "30d", average: true).ticks).to be_empty
    expect(chart([], numbers: []).ticks).to be_empty
  end
end
