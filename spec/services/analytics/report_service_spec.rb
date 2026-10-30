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

  def report(**options)
    described_class.new(user: user, **options).tap(&:call!)
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

  it "gives each page the numbers it has counted: a project its commits and site visits, every page Openstage's own" do
    app.site_visit_days.create!(day: 1.day.ago.to_date, visits: 30, visitors: 9)
    create(:profile_view, user: user, viewed_at: 2.days.ago)
    user.project_views.create!(repo_name: "me/lib", viewed_at: 1.day.ago, ip_hash: "b")

    expect(report.rows.to_h { |row| [ row.name, row.shown ] }).to eq("Your stage" => %w[visitors views], "app" => %w[commits visits],
                                                                     "lib" => %w[commits visitors views])
  end

  it "leaves out the numbers a project's builder hides from it, and never Openstage's own" do
    app.update!(hidden_numbers: %w[commits])
    user.project_views.create!(repo_name: "me/app", viewed_at: 1.day.ago, ip_hash: "b")
    service = report
    row = service.rows.find { |each| each.name == "app" }

    expect([ row.counted, row.shown ]).to eq([ %w[commits visitors views], %w[visitors views] ])
    expect(total(service, "commits").split.map { |each, count| [ each.name, count ] }).to eq([ [ "lib", 1 ] ])
  end

  it "opens on the last 30 days and commits alone, each point its own count, against the window before" do
    service = report
    commits = total(service, "commits")

    expect([ service.totals_window.range, service.drawn.map(&:key), commits.value, commits.previous ]).to eq([ "30d", %w[commits], 3, 1 ])
    expect(service.chart.lines.map(&:repo)).to contain_exactly("me/app", "me/lib")
    expect([ service.chart.average?, service.chart.note ]).to eq([ false, "Commits per day, one line per page." ])
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

    expect([ service.selected_keys, service.rows.map(&:on).uniq, service.totals_window.range ]).to eq([ [], [ true ], "30d" ])
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
    user.badge_impressions.create!(kind: "badge", viewed_at: 100.days.ago, referrer: "github.com", ip_hash: "x")
    recent = report

    expect([ recent.sources.map(&:first), recent.countries.map(&:first), recent.badges.first ]).to eq([ [ "Hacker News" ], [ "PT" ], [ "badge", 0, 0 ] ])
    ever = report(range: "all")
    expect([ ever.sources.map(&:first), ever.badges.first ]).to eq([ [ "Hacker News", "Twitter / X" ], [ "badge", 1, 1 ] ])
    expect(report(pages: %w[me/app]).sources).to eq([])
  end

  it "lists the links visitors followed, busiest first, on the pages in view" do
    entry = create(:entry, user: user, repo_name: "me/lib", entry_type: "milestone", source: "manual", title: "Launched", url: "https://lib.example")
    2.times { EntryClick.create!(user: user, entry: entry, clicked_at: 1.day.ago) }
    user.project_clicks.create!(repo_name: "me/app", kind: "github", clicked_at: 1.day.ago)

    expect(report.links.map { |link| [ link.title, link.page.name, link.count ] }).to eq([ [ "Launched", "lib", 2 ], [ "View on GitHub", "app", 1 ] ])
    expect(report(pages: [ "me/app" ]).links.map(&:title)).to eq([ "View on GitHub" ])
  end

  it "refuses without a builder" do
    expect(described_class.new.call).to be(false)
  end
end
