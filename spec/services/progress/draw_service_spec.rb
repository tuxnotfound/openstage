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
    Progress::Row.new(key: key, name: key.split("/").last, rank: rank, color_class: "os-project-#{rank + 1}", repo: nil, on: on, counted: shown, shown: shown)
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

  context "with a level" do
    let(:may) { Date.new(2026, 5, 1) }
    let(:counts) do
      Progress::Counts.new(days: { "commits" => { "me/app" => { today - 1 => 3 } }, "mrr" => { "me/app" => { may => 10.0, Date.new(2026, 8, 2) => 20.0, today => 30.0 } } },
                           firsts: { "commits" => { "me/app" => today - 1 }, "mrr" => { "me/app" => may } }, through: today, currency: "usd")
    end
    let(:level) { row("me/app", %w[commits mrr]) }

    it "totals what it stands at as the window ends, against where it stood as the window began" do
      expect(totals(draw([ level ]))["mrr"]).to eq([ 30.0, 20.0, [ [ "app", 30.0 ] ] ])
    end

    it "draws each point at what it stood at, in money, and never averages it" do
      thirty = Progress::Window.new(range: "30d", today: today, first_activity: nil)
      service = described_class.new(rows: [ level ], counts: counts, totals_window: thirty, show: %w[mrr], average: true).tap(&:call!)
      last = service.chart.columns.last

      expect(service.chart).not_to be_average
      expect(last.title).not_to include("average")
      expect(last.rows.first.values).to eq([ "$30" ])
      expect(service.chart.ticks.map(&:value)).to all(start_with("$"))
    end

    it "says which numbers are averaged when a level stands beside them" do
      thirty = Progress::Window.new(range: "30d", today: today, first_activity: nil)
      service = described_class.new(rows: [ level ], counts: counts, totals_window: thirty, show: %w[commits mrr], average: true).tap(&:call!)

      expect(service.chart.columns.last.title).to end_with(" · 7-day average of commits")
      expect(service.chart.columns.last.rows.first.values).to eq([ "0.4", "$30" ])
      expect(service.chart.aria_label).to start_with("MRR and 7-day average of commits per day by project")
    end

    it "draws a level that fell to nothing by the window's end" do
      stood = ((today - 50)..(today - 40)).to_h { |day| [ day, 10.0 ] }
      gone = Progress::Counts.new(days: { "mrr" => { "me/app" => stood } }, firsts: { "mrr" => { "me/app" => today - 50 } }, through: today, currency: "usd")
      service = described_class.new(rows: [ row("me/app", %w[mrr]) ], counts: gone, totals_window: totals_window, show: %w[mrr]).tap(&:call!)

      expect(service.chart.paths.size).to eq(1)
      expect(service.totals.first.value).to eq(0)
    end
  end

  it "starts each line on its own first day, so a number added later never draws zero before it counted" do
    service = draw([ app ], show: %w[commits visits])
    by_number = service.chart.paths.to_h { |d, _, number, _, start| [ number, [ d, start ] ] }

    expect(by_number["commits"].last).to eq(0)
    expect(by_number["visits"].last).to eq(service.window.buckets.size - 1)
    expect(by_number["commits"].first.scan(/[ML]/).size).to eq(service.window.buckets.size)
  end

  it "draws a number that began on the last point as a dot, since one vertex draws nothing" do
    d, = draw([ app ], show: %w[visits]).chart.paths.first

    expect(d).to match(/\AM[\d.]+ [\d.]+ L[\d.]+ [\d.]+\z/)
    expect(d.split(" L").map { |point| point.delete("M") }.uniq.size).to eq(1)
  end

  it "leaves a row out of view out of the totals and the chart, and keeps its value for the table" do
    service = draw([ app, row("me/lib", %w[commits], on: false, rank: 1) ])

    expect(totals(service)["commits"]).to eq([ 3, 2, [ [ "app", 3 ] ] ])
    expect(service.chart.lines.map(&:repo)).to eq([ "me/app" ])
    expect(service.cells(service.rows.last, [ Progress::Numbers.find("commits") ]).sole.to_h.slice(:value, :previous, :shown)).to eq(value: 1, previous: nil, shown: true)
  end

  it "fills a row's cells with what visitors see, and on the builder's own table what it counts and hides, its switch, or Set up" do
    repo = build(:github_repo, hidden_numbers: [ "visits" ])
    hiding = Progress::Row.new(key: "me/app", name: "app", rank: 0, color_class: "os-project-1", repo: repo, on: true,
                               counted: %w[commits visits], shown: %w[commits], site: :counting)
    plain = Progress::Row.new(key: "me/lib", name: "lib", rank: 1, color_class: "os-project-2", repo: repo, on: true,
                              counted: %w[commits], shown: %w[commits], site: :off)
    columns = Progress::Numbers.in_order(%w[commits visits])
    service = draw([ hiding, plain ])
    cell = ->(cells) { cells.map { |each| [ each.number.key, each.value, each.previous, each.shown, each.pick, each.link ] } }

    expect(cell.call(service.cells(hiding, columns))).to eq([ [ "commits", 3, 2, true, nil, nil ], [ "visits", nil, nil, false, nil, nil ] ])
    expect(cell.call(service.cells(hiding, columns, manage: true))).to eq([ [ "commits", 3, 2, true, true, nil ], [ "visits", 40, nil, false, false, nil ] ])
    expect(cell.call(service.cells(plain, columns, manage: true)).last).to eq([ "visits", nil, nil, false, nil, :set_up ])
  end

  it "gives site visits that do not count no switch: Paused or Set up instead, after the value only when the window has any" do
    repo = build(:github_repo)
    site = lambda do |key, state|
      Progress::Row.new(key: key, name: key.split("/").last, rank: 0, color_class: "os-project-1", repo: repo, on: true, counted: %w[visits], shown: [], site: state)
    end
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

  it "counts a row with no colour in the totals, with its part, and draws no line for it, nor starts the chart at its data" do
    old = Progress::Row.new(key: "me/old", name: "old", rank: 10, color_class: nil, repo: nil, on: true, counted: %w[visits], shown: %w[visits])
    all_time = Progress::Window.new(range: "all", today: today, first_activity: Date.new(2026, 1, 5))
    service = described_class.new(rows: [ app, old ], counts: counts, totals_window: all_time, show: %w[visits]).tap(&:call!)

    expect(totals(service)["visits"]).to eq([ 47, nil, [ [ "app", 40 ], [ "old", 7 ] ] ])
    expect(service.chart.lines.map(&:repo)).to eq([ "me/app" ])
    expect(service.window.first).to eq(Date.new(2026, 10, 26))
  end

  it "starts the chart where rows with no colour start when no row with one counts the numbers drawn, so its note says why it has no line" do
    old = Progress::Row.new(key: "me/old", name: "old", rank: 10, color_class: nil, repo: nil, on: true, counted: %w[visits], shown: %w[visits])
    all_time = Progress::Window.new(range: "all", today: today, first_activity: Date.new(2026, 1, 5))
    service = described_class.new(rows: [ row("me/app", %w[commits]), old ], counts: counts, totals_window: all_time, show: %w[visits], builder: true).tap(&:call!)

    expect(service.chart.lines).to be_empty
    expect(service.window.first).to eq(Date.new(2026, 1, 1))
    expect(service.chart.note).to eq("Only projects past the tenth count site visits, and the chart draws ten projects at most.")
  end

  it "words its chart by what its rows are" do
    expect(draw(per: "page").chart.aria_label).to start_with("Commits per week by page, ")
    expect(draw.chart.aria_label).to start_with("Commits per week by project, ")
  end

  describe "site visitors, which sit beside site visits" do
    # app shows both, lib its site visits alone; both counted visitors, and
    # each a commit.
    let(:counts) do
      Progress::Counts.new(
        days: { "commits" => { "me/app" => { today - 1 => 3 }, "me/lib" => { today - 1 => 1 } },
                "visits" => { "me/app" => { today - 2 => 40 }, "me/lib" => { today - 2 => 9 } },
                "site_visitors" => { "me/app" => { today - 2 => 12 }, "me/lib" => { today - 2 => 4 } } },
        firsts: { "commits" => { "me/app" => today - 1, "me/lib" => today - 1 }, "visits" => { "me/app" => today - 2, "me/lib" => today - 2 },
                  "site_visitors" => { "me/app" => today - 2, "me/lib" => today - 2 } }
      )
    end
    let(:app) { row("me/app", %w[commits visits site_visitors]) }
    let(:lib) { row("me/lib", %w[visits], rank: 1) }

    it "are no toggle, no line and never drawn, asked for or not, and the table still lists them" do
      service = draw(show: %w[site_visitors visits])

      expect([ service.shown, service.totals.map(&:number), service.drawn ].map { |numbers| numbers.map(&:key) })
        .to eq([ %w[commits visits site_visitors], %w[commits visits], %w[visits] ])
      expect(draw(show: %w[site_visitors], default_show: %w[commits visits]).drawn.map(&:key)).to eq(%w[commits visits])
      expect(service.chart.lines.map { |line| line.number.key }.uniq).to eq(%w[visits])
      expect(service.cells(app, service.shown).map(&:value)).to eq([ 3, 40, 12 ])
    end

    it "show for no row that leaves out site visits: no column of its table or its tooltip, and on the builder's own table their value alone" do
      hiding = row("me/app", %w[commits site_visitors])
      service = draw([ hiding ], show: %w[site_visitors visits])

      expect([ service.shown, service.totals.map(&:number), service.drawn, service.chart.tips ].map { |numbers| numbers.map(&:key) })
        .to eq([ %w[commits], %w[commits], %w[commits], %w[commits] ])
      expect(service.cells(hiding, Progress::Numbers.in_order(%w[site_visitors]), manage: true).sole.to_h.slice(:value, :shown, :pick))
        .to eq(value: 12, shown: false, pick: nil)
    end

    it "show in the tooltip beside each row's site visits, a dash for a row that does not show them" do
      chart = draw(show: %w[visits]).chart

      expect(chart.tips.map(&:key)).to eq(%w[visits site_visitors])
      expect(chart.columns.last.rows.map { |each| [ each.name, each.values ] }).to eq([ [ "app", %w[40 12] ], [ "lib", %w[9 –] ] ])
      expect(chart.indexed?).to be(false)
    end

    it "show beside a row's own site visits alone: a row that hides those has a dash for both, whatever else of it is drawn" do
      hiding = row("me/lib", %w[commits site_visitors], rank: 1)
      chart = draw([ app, hiding ], show: %w[commits visits]).chart

      expect(chart.tips.map(&:key)).to eq(%w[commits visits site_visitors])
      expect(chart.columns.last.rows.map { |each| [ each.name, each.values ] }).to eq([ [ "app", %w[3 40 12] ], [ "lib", %w[1 – –] ] ])
    end

    it "leave the tooltip with no column of theirs while no row in view shows them" do
      chart = draw([ row("me/app", %w[commits visits site_visitors], on: false), lib ], show: %w[visits]).chart

      expect(chart.tips.map(&:key)).to eq(%w[visits])
      expect(chart.columns.last.rows.map { |each| [ each.name, each.values ] }).to eq([ [ "lib", %w[9] ] ])
    end

    it "average to a tenth on a window drawn by day" do
      days = Progress::Window.new(range: "30d", today: today, first_activity: nil)
      chart = described_class.new(rows: [ app ], counts: counts, totals_window: days, show: %w[visits], average: true).tap(&:call!).chart

      expect(chart.columns.last.rows.sole.values).to eq(%w[5.7 1.7])
    end
  end

  it "shows no number for rows that show none" do
    service = draw([ row("me/app", []) ])

    expect([ service.totals, service.drawn, service.chart.note ]).to eq([ [], [], nil ])
  end

  it "needs the counts and the window" do
    expect(described_class.new(rows: [ app ], totals_window: totals_window).call).to be(false)
    expect(described_class.new(rows: [ app ], counts: counts).call).to be(false)
  end
end
