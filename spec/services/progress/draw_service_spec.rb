require "rails_helper"

RSpec.describe Progress::DrawService do
  # Wednesday: the 90-day view runs from Monday Aug 3, and the window before
  # it from May 4 to Jul 29.
  let(:today) { Date.new(2026, 10, 28) }
  let(:period) { Progress::Window.new(range: "90d", today: today, first_activity: nil) }
  let(:counts) do
    Progress::Counts.new(
      days: { "commits" => { "me/app" => { today - 1 => 3, Date.new(2026, 7, 1) => 2 }, "me/lib" => { today - 40 => 1 } },
              "visits" => { "me/app" => { today - 2 => 40 } } },
      firsts: { "commits" => { "me/app" => Date.new(2026, 7, 1), "me/lib" => today - 40 }, "visits" => { "me/app" => today - 2 } }
    )
  end
  let(:app) { row("me/app", %w[commits visits]) }
  let(:lib) { row("me/lib", %w[commits], rank: 1) }

  def row(key, shown, on: true, rank: 0)
    Progress::Row.new(key: key, name: key.split("/").last, rank: rank, repo: nil, on: on, counted: shown, shown: shown)
  end

  def draw(rows = [ app, lib ], **options)
    described_class.new(rows: rows, counts: counts, period: period, **options).tap(&:call!)
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
    expect(service.value(Progress::Numbers.find("commits"), service.rows.last)).to eq(1)
    expect(service.previous(Progress::Numbers.find("commits"), [ service.rows.last ])).to be_nil
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
    expect(described_class.new(rows: [ app ], period: period).call).to be(false)
    expect(described_class.new(rows: [ app ], counts: counts).call).to be(false)
  end
end
