require "rails_helper"

RSpec.describe Progress::DrawService do
  # Wednesday: the 90-day view runs from Monday Aug 3, and the window before
  # it from May 4 to Jul 29.
  let(:today) { Date.new(2026, 10, 28) }
  let(:totals_window) { Progress::Window.new(range: "90d", today: today, first_activity: nil) }
  let(:counts) do
    Progress::Counts.new(
      days: { "commits" => { "me/app" => { today - 1 => 3, Date.new(2026, 7, 1) => 2 }, "me/lib" => { today - 40 => 1 } },
              "visits" => { "me/app" => { today - 2 => 40 }, "me/old" => { Date.new(2026, 1, 5) => 7 } } },
      firsts: { "commits" => { "me/app" => Date.new(2026, 7, 1), "me/lib" => today - 40 }, "visits" => { "me/app" => today - 2, "me/old" => Date.new(2026, 1, 5) } }
    )
  end
  let(:app) { row("me/app", %w[commits visits]) }
  let(:lib) { row("me/lib", %w[commits], rank: 1) }

  def row(key, shown, on: true, rank: 0)
    Progress::Row.new(key: key, name: key.split("/").last, rank: rank, repo: nil, on: on, counted: shown, shown: shown)
  end

  def draw(rows = [ app, lib ], **options)
    described_class.new(rows: rows, counts: counts, totals_window: totals_window, **options).tap(&:call!)
  end

  def totals(service)
    service.totals.to_h { |total| [ total.number.key, [ total.value, total.previous, total.split.map { |each, count| [ each.name, count ] } ] ] }
  end

  it "totals each number a row shows over the window, with each row's part, against the window before while it counted before" do
    expect(totals(draw)).to eq("commits" => [ 4, 2, [ [ "app", 3 ], [ "lib", 1 ] ] ], "visits" => [ 40, nil, [ [ "app", 40 ] ] ])
  end

  it "totals no number for rows in view that do not show it, rather than nothing of it" do
    service = draw([ row("me/app", %w[commits visits], on: false), lib ])

    expect(totals(service)).to eq("commits" => [ 1, nil, [ [ "lib", 1 ] ] ], "visits" => [ nil, nil, [] ])
  end

  it "draws the numbers asked for in their line order, else the page's own, else the first, three at most" do
    expect(draw(show: %w[visits commits], default_show: %w[commits]).drawn.map(&:key)).to eq(%w[visits commits])
    expect(draw(show: %w[views], default_show: %w[visits]).drawn.map(&:key)).to eq(%w[visits])
    expect(draw.drawn.map(&:key)).to eq(%w[commits])
    expect(draw(show: %w[commits visits commits]).drawn.map(&:key)).to eq(%w[commits visits])
  end

  it "leaves a row out of view out of the totals and the chart, and keeps its value for the table" do
    service = draw([ app, row("me/lib", %w[commits], on: false, rank: 1) ])

    expect(totals(service)["commits"]).to eq([ 3, 2, [ [ "app", 3 ] ] ])
    expect(service.chart.lines.map(&:repo)).to eq([ "me/app" ])
    expect(service.cells(service.rows.last, [ Progress::Numbers.find("commits") ]).sole.to_h.slice(:value, :previous, :shown)).to eq(value: 1, previous: nil, shown: true)
  end

  it "fills a row's cells with what visitors see, and on the builder's own table what it counts and hides, its switch, or Set up" do
    repo = build(:github_repo, hidden_numbers: [ "visits" ])
    hiding = Progress::Row.new(key: "me/app", name: "app", rank: 0, repo: repo, on: true, counted: %w[commits visits], shown: %w[commits], site: :counting)
    plain = Progress::Row.new(key: "me/lib", name: "lib", rank: 1, repo: repo, on: true, counted: %w[commits], shown: %w[commits], site: :off)
    columns = Progress::Numbers.in_order(%w[commits visits])
    service = draw([ hiding, plain ])
    cell = ->(cells) { cells.map { |each| [ each.number.key, each.value, each.previous, each.shown, each.pick, each.link ] } }

    expect(cell.call(service.cells(hiding, columns))).to eq([ [ "commits", 3, 2, true, nil, nil ], [ "visits", nil, nil, false, nil, nil ] ])
    expect(cell.call(service.cells(hiding, columns, manage: true))).to eq([ [ "commits", 3, 2, true, true, nil ], [ "visits", 40, nil, false, false, nil ] ])
    expect(cell.call(service.cells(plain, columns, manage: true)).last).to eq([ "visits", nil, nil, false, nil, :set_up ])
  end

  it "gives site visits that do not count no switch: Paused or Set up instead, after the value only when the window has any" do
    repo = build(:github_repo)
    site = ->(key, state) { Progress::Row.new(key: key, name: key.split("/").last, rank: 0, repo: repo, on: true, counted: %w[visits], shown: [], site: state) }
    service = draw
    visits = ->(row) { service.cells(row, [ Progress::Numbers.find("visits") ], manage: true).sole.to_h.slice(:value, :shown, :pick, :link) }

    expect(visits.call(site.call("me/app", :paused))).to eq(value: 40, shown: false, pick: nil, link: :paused)
    expect(visits.call(site.call("me/app", :off))).to eq(value: 40, shown: false, pick: nil, link: :set_up)
    expect(visits.call(site.call("me/old", :off))).to eq(value: nil, shown: false, pick: nil, link: :set_up)
    expect(visits.call(site.call("me/old", :paused))).to eq(value: nil, shown: false, pick: nil, link: :paused)
  end

  it "starts the chart where the numbers drawn start, and draws each point's own count unless it averages" do
    service = draw(show: %w[visits])

    expect(service.window.first).to eq(Date.new(2026, 10, 26))
    expect(service.chart.lines.sole.values).to eq([ 40 ])
    expect(draw(show: %w[commits]).window.first).to eq(Date.new(2026, 8, 3))
  end

  it "words its chart by what its rows are" do
    expect(draw(per: "page").chart.note).to eq("Commits per week, one line per page.")
    expect(draw.chart.note).to eq("Commits per week, one line per project.")
  end

  it "shows no number for rows that show none" do
    service = draw([ row("me/app", []) ])

    expect([ service.totals, service.drawn, service.chart.note ]).to eq([ [], [], "No project here shows a number yet." ])
  end

  it "needs the counts and the window" do
    expect(described_class.new(rows: [ app ], totals_window: totals_window).call).to be(false)
    expect(described_class.new(rows: [ app ], counts: counts).call).to be(false)
  end
end
