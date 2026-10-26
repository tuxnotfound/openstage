require "rails_helper"

RSpec.describe Progress::NumbersService do
  let(:user) { create(:user, username: "builder", pro: true) }
  let!(:repo) do
    create(:github_repo, user: user, full_name: "builder/app", name: "app", homepage: "https://app.example",
                         site_source: "script", site_first_visit_at: 5.days.ago)
  end

  before do
    travel_to Time.utc(2026, 10, 26, 12)
    create(:entry, user: user, repo_name: "builder/app", occurred_at: 2.days.ago)
    # Work from before the window, so it has one before it to compare with.
    create(:entry, user: user, repo_name: "builder/app", occurred_at: 200.days.ago)
    repo.site_visit_days.create!(day: Date.new(2026, 10, 24), visits: 40, visitors: 12)
    repo.site_visit_days.create!(day: Date.new(2026, 7, 1), visits: 10, visitors: 4)
  end

  def numbers(range: "90d", **options)
    section = Progress::ComposeService.new(user: user, range: range, rolling: true).tap(&:call!).section
    described_class.new(user: user, section: section, **options).tap(&:call!).numbers
  end

  it "has commits, and the site visits the page shows, each with its total, the window before and each project's" do
    commits, visits = numbers

    expect([ commits.key, commits.total, commits.by_project ]).to eq([ "commits", 1, { "builder/app" => 1 } ])
    expect([ visits.key, visits.total, visits.before, visits.by_project ]).to eq([ "visits", 40, 10, { "builder/app" => 40 } ])
  end

  it "charts every number until some are picked, each on its own scale on the section's points" do
    expect(numbers.map { |number| number.chart.class }).to eq([ ProgressChart::Trend, ProgressChart::Series ])

    picked = numbers(picked: [ "visits" ])
    expect(picked.map { |number| number.chart.present? }).to eq([ false, true ])
    expect(picked.last.chart.ticks.map(&:value)).to eq([ 20, 40 ])
  end

  it "leaves out site visits a page hides, and keeps them for the builder's own view" do
    repo.update!(site_visits_shown: false)

    expect(numbers.map(&:key)).to eq([ "commits" ])
    expect(numbers(builder: true).map(&:key)).to eq(%w[commits visits])
  end

  it "needs a builder and a section" do
    expect(described_class.new.call).to be(false)
  end
end
