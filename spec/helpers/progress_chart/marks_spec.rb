require "rails_helper"

RSpec.describe ProgressChart::Marks do
  let(:commits) { Progress::Numbers.find("commits") }
  let(:visits) { Progress::Numbers.find("visits") }
  # Wednesday Oct 28; the work began on Monday Oct 19, so the 30-day view
  # has ten days, Oct 19 its first point.
  let(:window) { Progress::Window.new(range: "30d", today: Date.new(2026, 10, 28), first_activity: Date.new(2026, 10, 19)) }

  def line(repo, number, values, rank: 0)
    ProgressChart::Compare::Line.new(repo: "me/#{repo}", name: repo, rank: rank, color_class: "os-project-#{rank + 1}", number: number, values: values,
                                     total: values.sum)
  end

  def item(id, day, repo: "me/app", kind: :shipped)
    entry = Entry.new(id: id, title: "Entry #{id}", repo_name: repo)
    Progress::TallyService::Item.new(entry: entry, date: Date.new(2026, 10, day), kind: kind, listed: true)
  end

  def marks(items, lines: [ line("app", commits, Array.new(10, 2)), line("app", visits, Array.new(10, 8)) ], numbers: [ visits, commits ])
    ProgressChart::Compare.new(window: window, lines: lines, numbers: numbers, items: items).marks
  end

  it "sits on its project's line of the first number drawn in the pages' order, wherever the page draws it" do
    drawn = line("app", commits, [ 0, 0, 0, 0, 4, 0, 0, 0, 0, 0 ])
    chart = ProgressChart::Compare.new(window: window, lines: [ drawn, line("app", visits, Array.new(10, 8)) ], numbers: [ visits, commits ],
                                       items: [ item(1, 23) ])
    mark = chart.marks.sole

    expect(mark).to have_attributes(key: "me/app", number: "commits", color_class: "os-project-1", column: 4)
    expect([ mark.left, mark.top ]).to eq(chart.spot(4, drawn))
    expect(mark.top).to be < 100
  end

  it "keeps one mark per project and point, newest first, shipped while any entry is" do
    found = marks([ item(1, 23, kind: :published), item(2, 23), item(3, 23, repo: "me/lib", kind: :published),
                    item(4, 24, kind: :published) ], lines: [ line("app", commits, Array.new(10, 2)), line("lib", commits, Array.new(10, 1), rank: 1) ])

    expect(found.map { |mark| [ mark.key, mark.column, mark.items.map(&:id), mark.shipped? ] })
      .to eq([ [ "me/app", 4, [ 2, 1 ], true ], [ "me/lib", 4, [ 3 ], false ], [ "me/app", 5, [ 4 ], false ] ])
  end

  it "sits on the axis in ink with no project, and in its colour where its project has no line" do
    quiet = line("lib", commits, Array.new(10, 0), rank: 1)
    found = marks([ item(1, 20, repo: nil), item(2, 21, repo: "me/lib") ], lines: [ line("app", commits, Array.new(10, 2)), quiet ], numbers: [ commits ])

    expect(found.map { |mark| [ mark.key, mark.number, mark.color_class, mark.top ] })
      .to eq([ [ nil, nil, "os-project-none", 100.0 ], [ "me/lib", nil, "os-project-2", 100.0 ] ])
  end

  it "marks nothing before the chart's first point, and nothing without entries" do
    expect(marks([ item(1, 2) ])).to be_empty
    expect(marks([])).to be_empty
  end
end
