require "rails_helper"
require "open3"
require "support/progress_data"

# The charts recompute every window in the browser (app/javascript/charts).
# This spec writes what the server sends with a page and what the server
# itself counts, for every window and a few picks, and runs the browser's
# code over it (spec/javascript/parity.test.ts): any number that differs
# fails here. It needs Node, as the page's bundle does.
RSpec.describe "The charts' numbers in the browser" do
  include ProgressData

  let(:user) { create(:user, time_zone: "Europe/Lisbon") }
  let(:fixture) { Rails.root.join("tmp/parity/charts.json") }

  before { travel_to ProgressData::TODAY }

  it "match the server's for every window and pick" do
    seed_progress_data(user)
    seed_visits

    FileUtils.mkdir_p(fixture.dirname)
    File.write(fixture, { progress: progress, analytics: analytics }.to_json)
    output, status = Open3.capture2e({ "PARITY_FIXTURE" => fixture.to_s }, "npx", "vitest", "run", "spec/javascript/parity.test.ts", chdir: Rails.root.to_s)

    expect(status).to be_success, output
    expect(output).to match(/Tests\s+\d+ passed/)
  end

  def progress
    picks = [ [], [ progress_repo(0) ], [ progress_repo(0), progress_repo(4) ], [ progress_repo(1), progress_repo(2), progress_repo(3) ] ]
    cases = Progress::Window::RANGES.product(picks).map { |range, repos| progress_case(range, repos) }
    { data: Progress::ExportService.new(user: user).tap(&:call!).payload, cases: cases }
  end

  def progress_case(range, repos)
    section = Progress::ComposeService.new(user: user, range: range, repos: repos, rolling: true).tap(&:call!).section
    tally = section.tally
    arrow, words, = helpers.progress_change(section)
    { range: range, selected: repos, commits: tally.totals.commits, previous: tally.previous_totals&.commits,
      shipped: tally.totals.shipped, published: tally.totals.published, activeDays: tally.totals.active_days,
      projects: tally.totals.projects, scope: helpers.progress_scope(section), change: [ arrow, words ].compact_blank.join(" "),
      items: tally.items.size,
      lines: ProgressChart::Trend.new(section).lines.to_h { |line| [ line.repo, line.values.map { |value| value.round(3) } ] } }
  end

  def analytics
    picks = [ [], [ "page" ], [ progress_repo(0), progress_repo(4) ] ]
    cases = Analytics::Window::RANGES.keys.product(%w[visitors clicks], picks).map { |range, metric, picked| analytics_case(range, metric, picked) }
    { data: Analytics::ExportService.new(user: user).tap(&:call!).payload, cases: cases }
  end

  def analytics_case(range, metric, picked)
    report = Analytics::ReportService.new(user: user, range: range, metric: metric, picked: picked).tap(&:call!)
    metrics = Analytics::CountService::METRICS
    { range: range, metric: metric, picked: picked,
      totals: metrics.index_with { |each| report.total(each) }, changes: metrics.index_with { |each| report.change(each) },
      sources: report.sources, countries: report.countries,
      links: report.links.map { |link| [ link.title, link.page.key, link.count ] },
      badges: report.shown }
  end

  # Visits, follows and clicks over both windows, late in the day so the zone matters.
  def seed_visits
    repo = create(:github_repo, user: user, full_name: progress_repo(0), name: "openstage", homepage: "https://openstage.dev")
    entry = user.entries.where(repo_name: progress_repo(4)).highlights.first
    entry.update!(url: "https://trainedon.me")
    150.times do |i|
      at = (i % 120).days.ago.change(hour: 23, min: 30)
      create(:profile_view, user: user, viewed_at: at, ip_hash: "p#{i % 7}", referrer: %w[news.ycombinator.com x.com github.com].at(i % 4), country: %w[PT US DE].at(i % 5))
      user.project_views.create!(repo_name: progress_repo(i % 2 * 4), viewed_at: at, ip_hash: "v#{i % 5}", referrer: "bsky.app", country: "GB")
      EntryClick.create!(user: user, entry: entry, clicked_at: at) if (i % 3).zero?
      user.project_clicks.create!(repo_name: progress_repo(0), kind: %w[visit github].at(i % 2), clicked_at: at) if (i % 4).zero?
      user.badge_impressions.create!(kind: %w[badge embed].at(i % 2), viewed_at: at, referrer: "site#{i % 3}.example", ip_hash: "b#{i}") if (i % 5).zero?
    end
    3.times { |i| user.subscriptions.create!(email: "f#{i}@example.com", github_repo: (repo if i.odd?), confirmed_at: (i * 20).days.ago) }
  end

  def helpers
    ApplicationController.helpers
  end
end
