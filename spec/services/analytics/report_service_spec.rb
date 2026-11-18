require "rails_helper"

RSpec.describe Analytics::ReportService do
  let(:user) { create(:user, pro: true) }
  let!(:app) { create(:github_repo, user: user, full_name: "me/app", name: "app") }

  # Saturday: the 30-day view runs from Sep 25, the window before it from
  # Aug 26 to Sep 24.
  before do
    travel_to Time.utc(2026, 10, 24, 12)
    2.times { create(:entry, user: user, repo_name: "me/app", occurred_at: 2.days.ago) }
    create(:entry, user: user, repo_name: "me/lib", occurred_at: 3.days.ago)
    create(:entry, user: user, repo_name: "me/app", occurred_at: 40.days.ago)
  end

  # Overview unless a tab is named.
  def report(tab: nil, **options)
    described_class.new(user: user, tab: Analytics::Tab.find(tab), **options).tap(&:call!)
  end

  def total(service, key)
    service.totals.find { |each| each.number.key == key }
  end

  it "has a row per page, the builder's own first, then each project in the public page's order and colours" do
    rows = report.rows

    expect(rows.map { |row| [ row.key, row.name, row.rank, row.color_class ] })
      .to eq([ [ "page", "Your stage", nil, "os-project-none" ], [ "me/app", "app", 0, "os-project-1" ], [ "me/lib", "lib", 1, "os-project-2" ] ])
  end

  it "gives a project's page past the tenth no colour, and never puts it in view by name" do
    8.times { |i| create(:entry, user: user, repo_name: "me/p#{i}", occurred_at: 2.days.ago) }
    create(:entry, user: user, repo_name: "me/quiet", occurred_at: 2.days.ago)

    service = report(pages: %w[me/quiet])
    expect(service.rows.last).to have_attributes(key: "me/quiet", color_class: nil, on: true)
    expect(service.selected_keys).to eq([])
    expect(service.chart.lines.map(&:repo)).not_to include("me/quiet")
    expect(report(pages: %w[me/quiet me/lib]).selected_keys).to eq([ "me/lib" ])
    expect(report(pages: %w[page me/app me/lib] + (0..7).map { |i| "me/p#{i}" }).selected_keys).to eq([])
  end

  it "gives each page the numbers it has counted: a project its commits, site visits and site visitors, every page Openstage's own" do
    app.site_visit_days.create!(day: 1.day.ago.to_date, visits: 30, visitors: 9)
    create(:profile_view, user: user, viewed_at: 2.days.ago)
    user.project_views.create!(repo_name: "me/lib", viewed_at: 1.day.ago, ip_hash: "b")

    expect(report.rows.to_h { |row| [ row.name, row.shown ] }).to eq("Your stage" => %w[views visitors], "app" => %w[commits visits site_visitors],
                                                                     "lib" => %w[commits views visitors])
  end

  it "sums site visitors over the window in each project's cell, picked days included, with the window before's, and has no toggle of them" do
    lib = create(:github_repo, user: user, full_name: "me/lib", name: "lib")
    app.site_visit_days.create!(day: Date.new(2026, 9, 1), visits: 10, visitors: 4)
    app.site_visit_days.create!(day: Date.new(2026, 10, 3), visits: 30, visitors: 9)
    app.site_visit_days.create!(day: Date.new(2026, 10, 20), visits: 12, visitors: 6)
    lib.site_visit_days.create!(day: Date.new(2026, 10, 4), visits: 8, visitors: 5)
    visitors = ->(service) { service.rows.to_h { |row| [ row.name, service.cells(row).find { |cell| cell.number.key == "site_visitors" }.to_h.slice(:value, :previous) ] } }

    service = report
    expect(visitors.call(service)).to eq("Your stage" => { value: nil, previous: nil }, "app" => { value: 15, previous: 4 }, "lib" => { value: 5, previous: nil })
    expect(total(service, "site_visitors")).to be_nil
    expect(visitors.call(report(range: "2026-10-01..2026-10-10")).transform_values { |cell| cell[:value] }).to eq("Your stage" => nil, "app" => 9, "lib" => 5)
  end

  it "never draws site visitors, asked for or not, and shows them in the tooltip beside the site visits of a project that shows both" do
    app.site_visit_days.create!(day: 2.days.ago.to_date, visits: 30, visitors: 9)

    service = report(show: %w[site_visitors visits])
    expect([ service.drawn.map(&:key), service.chart.tips.map(&:key) ]).to eq([ %w[visits], %w[visits site_visitors] ])
    expect(service.chart.columns.find { |column| column.rows.any? }.rows.map { |row| [ row.name, row.values ] }).to eq([ [ "app", %w[30 9] ] ])
    expect(report(show: %w[site_visitors]).drawn.map(&:key)).to eq(%w[commits visits])
  end

  it "shows a project's site visits and site visitors whatever its builder hides from visitors" do
    app.site_visit_days.create!(day: 2.days.ago.to_date, visits: 30, visitors: 9)

    [ %w[visits], %w[site_visitors], %w[visits site_visitors], [] ].each do |hidden|
      app.update!(hidden_numbers: hidden)
      service = report(show: %w[visits])

      expect([ service.rows.find(&:repo).shown, service.chart.tips.map(&:key) ]).to eq([ %w[commits visits site_visitors], %w[visits site_visitors] ])
    end
  end

  it "never draws Openstage's own visitors, asked for or not, shows them in the tooltip right after views, and keeps them in the table" do
    create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "a")
    create(:profile_view, user: user, viewed_at: 2.days.ago, ip_hash: "b")

    service = report(show: %w[visitors views])
    expect([ service.drawn, service.totals.map(&:number), service.chart.tips ].map { |numbers| numbers.map(&:key) }).to eq([ %w[views], %w[commits views], %w[views visitors] ])
    expect(service.columns.map(&:key)).to eq(%w[commits visits views visitors])
    expect(service.chart.columns.find { |column| column.rows.any? }.rows.map { |row| [ row.name, row.values ] }).to eq([ [ "Your stage", %w[2 2] ] ])
    expect(report(show: %w[visitors]).drawn.map(&:key)).to eq(%w[commits])
  end

  it "keeps the numbers a project's builder hides from visitors, since only the builder sees this page" do
    app.update!(hidden_numbers: %w[commits])
    user.project_views.create!(repo_name: "me/app", viewed_at: 1.day.ago, ip_hash: "b")
    service = report
    row = service.rows.find { |each| each.name == "app" }

    expect([ row.counted, row.shown ]).to eq([ %w[commits views visitors], %w[commits views visitors] ])
    expect(total(service, "commits").split.map { |each, _| each.name }).to include("app", "lib")
  end

  it "opens on the last 30 days and on commits, site visits and MRR as far as they count, each point its own count, against the window before" do
    service = report
    commits = total(service, "commits")

    expect([ service.totals_window.range, service.drawn.map(&:key), commits.value, commits.previous ]).to eq([ "30d", %w[commits], 3, 1 ])
    expect(service.chart.lines.map(&:repo)).to contain_exactly("me/app", "me/lib")
    expect([ service.chart.average?, service.chart.note, service.chart.aria_label ]).to eq([ false, nil, "Commits per day by page, last 30 days" ])
    expect(service.cells(service.rows.last).find { |cell| cell.number.key == "commits" }.previous).to be_nil
  end

  it "draws the numbers asked for on the pages asked for" do
    create(:profile_view, user: user, viewed_at: 2.days.ago)
    service = report(show: %w[views commits], pages: %w[page me/lib])

    expect([ service.drawn.map(&:key), service.selected_keys ]).to eq([ %w[views commits], %w[page me/lib] ])
    expect(service.chart.lines.map { |line| [ line.repo, line.number.key ] }).to contain_exactly(%w[page views], %w[me/lib commits])
    expect([ service.chart.indexed?, service.window.first ]).to eq([ true, 3.days.ago.to_date ])
  end

  it "shows every page for pages it does not know, and the last 30 days for a window it does not know" do
    service = report(pages: %w[me/nope], range: "7d")

    expect([ service.selected_keys, service.rows.reject(&:idle).map(&:on).uniq, service.totals_window.range ]).to eq([ [], [ true ], "30d" ])
    expect(service.rows.first).to have_attributes(key: "page", idle: true, on: false)
  end

  it "draws 12 months by week while the data is under 13 weeks old, then by month, and all time from where it starts" do
    expect(report(range: "12m").window.unit).to eq(:week)

    create(:entry, user: user, repo_name: "me/lib", occurred_at: 200.days.ago)
    year = report(range: "12m")
    expect([ year.window.unit, year.window.first, year.window.buckets.size ]).to eq([ :month, Date.new(2026, 4, 1), 7 ])
    ever = report(range: "all")
    expect([ ever.window.first, total(ever, "commits").value, total(ever, "commits").previous ]).to eq([ Date.new(2026, 4, 1), 5, nil ])
  end

  it "reads where visitors came from and the badge's showings over the window, every day for all time" do
    create(:profile_view, user: user, viewed_at: 2.days.ago, referrer: "news.ycombinator.com", country: "PT")
    create(:profile_view, user: user, viewed_at: 100.days.ago, referrer: "x.com", country: "US")
    user.badge_impressions.create!(kind: "badge", viewed_at: 100.days.ago, referrer: "github.com")
    recent = report(tab: "openstage")

    expect([ recent.sources.rows.map(&:first), recent.countries.rows.map(&:first), recent.badges.first ]).to eq([ [ "Hacker News" ], [ "PT" ], [ "badge", 0, 0 ] ])
    ever = report(tab: "openstage", range: "all")
    expect([ ever.sources.rows.map(&:first), ever.badges.first ]).to eq([ [ "Hacker News", "Twitter / X" ], [ "badge", 1, 1 ] ])
    user.project_views.create!(repo_name: "me/app", viewed_at: 100.days.ago, ip_hash: "c")
    expect(report(tab: "openstage", pages: %w[me/app]).sources.rows).to eq([])
  end

  it "lists eight sources and eight countries, with what each leaves out, and leaves out Cloudflare's XX and T1" do
    hosts = %w[a.example b.example c.example d.example e.example f.example g.example h.example i.example]
    codes = %w[PT ES FR DE IT NL BE SE DK]
    hosts.each_with_index { |host, i| (10 - i).times { create(:profile_view, user: user, viewed_at: 2.days.ago, referrer: host, country: codes[i]) } }
    %w[XX T1].each { |code| create(:profile_view, user: user, viewed_at: 2.days.ago, referrer: "a.example", country: code) }

    service = report(tab: "openstage")
    expect(service.sources).to eq(Analytics::Ranked.new(rows: [ [ "a.example", 10 + 2 ] ] + hosts[1, 7].each_with_index.map { |host, i| [ host, 9 - i ] }, other: 2))
    expect(service.countries).to eq(Analytics::Ranked.new(rows: codes.first(8).each_with_index.map { |code, i| [ code, 10 - i ] }, other: 2))
  end

  it "names the sources of the builder's pages as the website panels do: Openstage's own, and any other host as itself" do
    [ "openstage.dev", "www.IndieHackers.com", "news.ycombinator.com", nil ].each { |host| create(:profile_view, user: user, viewed_at: 2.days.ago, referrer: host) }

    expect(report(tab: "openstage").sources.rows).to eq([ [ "Direct", 1 ], [ "Hacker News", 1 ], [ "Openstage", 1 ], [ "indiehackers.com", 1 ] ])
  end

  it "counts a host that names no site, an address or a machine on someone's network, in Other, which stays last" do
    %w[localhost pedros-macbook-pro.local 192.168.1.23 news.ycombinator.com].each { |host| create(:profile_view, user: user, viewed_at: 2.days.ago, referrer: host) }

    expect(report(tab: "openstage").sources).to eq(Analytics::Ranked.new(rows: [ [ "Hacker News", 1 ] ], other: 3))
  end

  it "lists the links visitors followed, busiest first, on the pages in view" do
    entry = create(:entry, user: user, repo_name: "me/lib", entry_type: "milestone", source: "manual", title: "Launched", url: "https://lib.example")
    2.times { EntryClick.create!(user: user, entry: entry, clicked_at: 1.day.ago) }
    user.project_clicks.create!(repo_name: "me/app", kind: "github", clicked_at: 1.day.ago)

    expect(report(tab: "openstage").links.rows.map { |link| [ link.title, link.page.name, link.count ] }).to eq([ [ "Launched", "lib", 2 ], [ "View on GitHub", "app", 1 ] ])
    expect(report(tab: "openstage", pages: [ "me/app" ]).links.rows.map(&:title)).to eq([ "View on GitHub" ])
  end

  it "reads the website lists on Site visits alone: of every project of the builder's while all are in view, of the projects in view otherwise" do
    hidden = create(:github_repo, user: user, full_name: "me/hidden", name: "hidden")
    lib = create(:github_repo, user: user, full_name: "me/lib", name: "lib")
    app.site_visit_days.create!(day: 2.days.ago.to_date, visits: 2, visitors: 1)
    lib.site_visit_days.create!(day: 2.days.ago.to_date, visits: 1, visitors: 1)
    app.site_visit_counts.create!(kind: "page", value: "/app", count: 2, day: 2.days.ago.to_date)
    hidden.site_visit_counts.create!(kind: "page", value: "/hidden", count: 1, day: 2.days.ago.to_date)
    app.site_visit_counts.create!(kind: "page", value: "/before", count: 5, day: 40.days.ago.to_date)

    visits = report(tab: "visits")
    expect(visits.rows.map(&:key)).to eq(%w[me/app me/lib])
    expect(visits.websites.ranks["page"].rows).to eq([ [ "/app", 2, "me/app" ], [ "/hidden", 1, "me/hidden" ] ])
    expect(report(tab: "visits", range: "90d").websites.ranks["page"].rows).to eq([ [ "/before", 5, "me/app" ], [ "/app", 2, "me/app" ], [ "/hidden", 1, "me/hidden" ] ])
    expect(report(tab: "visits", pages: %w[me/app]).websites.ranks["page"].rows).to eq([ [ "/app", 2, nil ] ])
    only_lib = report(tab: "visits", pages: %w[me/lib])
    expect([ only_lib.websites.state, only_lib.setup_row.name ]).to eq([ :off, "lib" ])
    expect([ report.websites, report.on_pages, report(tab: "openstage").websites, visits.on_pages ]).to all(be_nil)
  end

  it "lists each tab's numbers in its order, a figure for the ones beside another, and its rows as the tab says" do
    app.site_visit_days.create!(day: 2.days.ago.to_date, visits: 30, visitors: 9)
    create(:profile_view, user: user, viewed_at: 2.days.ago)

    overview = report
    expect([ overview.columns, overview.tiles.map(&:number) ].map { |numbers| numbers.map(&:key) }).to eq([ %w[commits visits site_visitors views visitors], %w[commits visits views] ])
    expect([ overview.rows.map(&:key), overview.per, overview.drawn.map(&:key) ]).to eq([ %w[page me/app me/lib], "page", %w[commits visits] ])

    commits = report(tab: "commits")
    expect([ commits.rows.map(&:key), commits.columns.map(&:key), commits.drawn.map(&:key), commits.per ]).to eq([ %w[me/app me/lib], %w[commits], %w[commits], "project" ])

    visits = report(tab: "visits")
    expect(visits.rows.map { |row| [ row.key, row.boxed?, row.on ] }).to eq([ [ "me/app", true, true ], [ "me/lib", false, false ] ])
    expect(visits.tiles.map { |total| [ total.number.key, total.value ] }).to eq([ [ "visits", 30 ], [ "site_visitors", 9 ] ])
    expect(visits.selected_keys).to eq([])

    openstage = report(tab: "openstage")
    expect([ openstage.rows.map(&:key), openstage.columns.map(&:key), openstage.drawn.map(&:key) ]).to eq([ %w[page me/app me/lib], %w[views visitors], %w[views] ])
  end

  it "reads Free's commits and its one project's site visits alone, with no stage, whatever its other projects counted on Pro" do
    lib = create(:github_repo, user: user, full_name: "me/lib", name: "lib")
    app.update!(site_source: "script", site_set_up_at: 20.days.ago)
    lib.update!(site_source: "script", site_set_up_at: 10.days.ago)
    app.site_visit_days.create!(day: 2.days.ago.to_date, visits: 30, visitors: 9)
    lib.site_visit_days.create!(day: 2.days.ago.to_date, visits: 7, visitors: 3)
    app.site_visit_counts.create!(kind: "page", value: "/app", count: 30, day: 2.days.ago.to_date)
    lib.site_visit_counts.create!(kind: "page", value: "/lib", count: 7, day: 2.days.ago.to_date)
    create(:profile_view, user: user, viewed_at: 2.days.ago)
    product = user.revenue_accounts.create!(provider: "stripe", api_key: "rk_test_ok", read_at: Time.current, read_through: Date.current)
                  .revenue_products.create!(external_id: "prod_m", name: "Monthly", github_repo: app)
    product.revenue_days.create!(day: 3.days.ago.to_date, currency: "usd", mrr: 1_000, subscriptions: 1)
    user.update!(pro: false)

    service = report
    expect([ service.rows.map(&:key), service.columns.map(&:key), service.tiles.map { |total| [ total.number.key, total.value ] } ])
      .to eq([ %w[me/app me/lib], %w[commits visits site_visitors], [ [ "commits", 3 ], [ "visits", 30 ] ] ])
    expect(service.cells(service.rows.last).map { |cell| [ cell.number.key, cell.value, cell.link ] }).to eq([ [ "commits", 1, nil ], [ "visits", nil, :paused ], [ "site_visitors", nil, nil ] ])
    expect(%w[mrr customers views].map { |key| service.counts.first_day(key, %w[page me/app me/lib]) }).to all(be_nil)
    expect(report(tab: "visits").websites.ranks["page"].rows).to eq([ [ "/app", 30, nil ] ])
  end

  it "marks on the chart what the pages in view shipped and published over the window, the stage's on the axis" do
    create(:entry, user: user, repo_name: "me/app", entry_type: "milestone", source: "manual", title: "Launched", occurred_at: 3.days.ago)
    create(:entry, user: user, entry_type: "milestone", source: "manual", title: "On my stage", occurred_at: 2.days.ago)
    create(:entry, user: user, repo_name: "me/app", entry_type: "milestone", source: "manual", title: "Long ago", occurred_at: 60.days.ago)
    create(:profile_view, user: user, viewed_at: 2.days.ago)

    marks = ->(**options) { report(**options).chart.marks.map { |mark| [ mark.key, mark.number, mark.items.map(&:title) ] } }
    expect(marks.call).to contain_exactly([ "me/app", "commits", [ "Launched" ] ], [ nil, nil, [ "On my stage" ] ])
    expect(marks.call(pages: %w[me/lib])).to eq([])
    expect(marks.call(tab: "commits")).to eq([ [ "me/app", "commits", [ "Launched" ] ] ])
  end

  it "keeps a project past the palette in the totals, with no colour and no line" do
    10.times { |i| create(:entry, user: user, repo_name: "me/p#{i}", occurred_at: 2.days.ago) }

    service = report(tab: "commits")
    expect(service.rows.size).to eq(12)
    expect(service.rows.last(2).map(&:color_class)).to eq([ nil, nil ])
    expect(service.totals.sole.value).to eq(2 + 1 + 10)
  end

  it "refuses without a builder" do
    expect(described_class.new.call).to be(false)
  end
end
