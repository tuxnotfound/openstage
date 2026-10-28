require "rails_helper"

RSpec.describe Progress::ChartService do
  let(:user) { create(:user, username: "builder", pro: true) }
  let!(:app) do
    create(:github_repo, user: user, full_name: "builder/app", name: "app", homepage: "https://app.example",
                         site_source: "script", site_first_visit_at: 10.days.ago)
  end
  let!(:lib) { create(:github_repo, user: user, full_name: "builder/lib", name: "lib") }

  # Wednesday: the 90-day view starts on Monday Aug 3, and the window before
  # it runs from May 4 to Jul 29.
  before do
    travel_to Time.utc(2026, 10, 28, 12)
    3.times { |i| create(:entry, user: user, repo_name: "builder/app", occurred_at: (i + 1).days.ago) }
    create(:entry, user: user, repo_name: "builder/lib", occurred_at: 40.days.ago)
    create(:entry, user: user, repo_name: "builder/app", occurred_at: 120.days.ago)
    app.site_visit_days.create!(day: Date.new(2026, 10, 26), visits: 40, visitors: 12)
  end

  def chart(**options)
    described_class.new(user: user, range: "90d", **options).tap(&:call!)
  end

  def totals(service)
    service.totals.to_h { |total| [ total.number.key, [ total.value, total.split.map { |row, count| [ row.name, count ] } ] ] }
  end

  it "totals every number the projects show over the window, with each project's part, and draws the page's own two" do
    service = chart

    expect(totals(service)).to eq("commits" => [ 4, [ [ "app", 3 ], [ "lib", 1 ] ] ], "visits" => [ 40, [ [ "app", 40 ] ] ])
    expect(service.drawn.map(&:key)).to eq(%w[commits visits])
    expect(service.chart.lines.map { |line| [ line.repo, line.number.key ] })
      .to contain_exactly([ "builder/app", "commits" ], [ "builder/lib", "commits" ], [ "builder/app", "visits" ])
  end

  it "draws the numbers asked for, in their line order, and only numbers the page shows" do
    expect(chart(show: %w[visits commits]).drawn.map(&:key)).to eq(%w[visits commits])
    expect(chart(show: %w[visits]).drawn.map(&:key)).to eq(%w[visits])
    expect(chart(show: %w[views]).drawn.map(&:key)).to eq(%w[commits visits])
  end

  it "compares a number with the window before only when it counted before the window began" do
    commits, visits = chart.totals

    expect([ commits.previous, visits.previous ]).to eq([ 1, nil ])
  end

  it "starts the chart where the numbers drawn start" do
    expect(chart(show: %w[visits]).window.first).to eq(Date.new(2026, 10, 26))
    expect(chart(show: %w[commits]).window.first).to eq(Date.new(2026, 8, 3))
  end

  it "leaves out of every number, and of the chart, what a project hides from visitors" do
    app.update!(hidden_numbers: [ "commits" ])
    service = chart

    expect(totals(service)["commits"]).to eq([ 1, [ [ "lib", 1 ] ] ])
    expect(service.chart.lines.select { |line| line.number.key == "commits" }.map(&:repo)).to eq([ "builder/lib" ])
  end

  it "keeps for the builder's own view the numbers visitors do not see, the projects hidden from their page, and site visits to set up" do
    app.update!(hidden_numbers: [ "visits" ])
    create(:github_repo, user: user, full_name: "builder/old", name: "old", included: false)
    create(:entry, user: user, repo_name: "builder/old", occurred_at: 2.days.ago)
    expect(totals(chart).keys).to eq(%w[commits])

    builder = chart(builder: true)
    row = builder.rows.find { |each| each.name == "app" }
    expect([ row.counts?("visits"), row.shows?("visits") ]).to eq([ true, false ])
    expect(builder.cells(row).to_h { |cell| [ cell.number.key, [ cell.value, cell.pick ] ] }).to eq("commits" => [ 3, true ], "visits" => [ 40, false ])
    expect(builder.columns.map(&:key)).to eq(%w[commits visits])
    expect(builder.off_page.map(&:name)).to eq([ "old" ])
    expect(builder.chart.lines.map { |line| line.number.key }.uniq).to eq(%w[commits])
  end

  it "shows a project's page that project alone" do
    service = chart(repos: [ "builder/lib" ], lone: true)

    expect(service.rows.map(&:name)).to eq([ "lib" ])
    expect(totals(service).keys).to eq(%w[commits])
  end

  it "shows every project for a list that names none of theirs, or every one" do
    [ [ "builder/nope" ], %w[builder/lib builder/app] ].each do |repos|
      service = chart(repos: repos)

      expect(service.section.filtered?).to be(false)
      expect([ service.selected_keys, service.rows.map(&:on) ]).to eq([ [], [ true, true ] ])
    end
  end

  it "keeps a project's page on its project when it is the builder's only one" do
    lib.destroy!
    user.entries.where(repo_name: "builder/lib").delete_all

    service = chart(repos: [ "builder/app" ], lone: true)

    expect([ service.section.filtered?, service.rows.map(&:name) ]).to eq([ true, [ "app" ] ])
  end

  it "needs a builder" do
    expect(described_class.new.call).to be(false)
  end
end
