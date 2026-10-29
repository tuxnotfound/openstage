require "rails_helper"
require "support/progress_data"

RSpec.describe Progress::TallyService do
  include ProgressData

  let(:user) { create(:user) }

  before do
    seed_progress_data(user)
    travel_to ProgressData::TODAY
  end

  def tally(range, offset: 0, repo: nil)
    described_class.new(user: user, range: range, offset: offset, repos: Array(repo)).tap(&:call!)
  end

  def numbers(totals)
    [ totals.shipped, totals.published, totals.commits, totals.active_days, totals.projects ]
  end

  it "counts 2026 as the design round did" do
    year = tally("year")

    expect(numbers(year.totals)).to eq([ 10, 10, 380, 64, 7 ])
    expect(year.previous_totals).to be_nil
    expect(year.first_active_day).to eq(Date.new(2026, 3, 23))
  end

  it "counts October against September 1 to 15" do
    october = tally("month")

    expect(numbers(october.totals).first(3)).to eq([ 1, 2, 150 ])
    expect(numbers(october.previous_totals).first(3)).to eq([ 1, 1, 23 ])
  end

  it "counts Week 42's commits, with nothing logged" do
    week = tally("week")

    expect(week.totals.commits).to eq(79)
    expect(week.items).to be_empty
    expect(week.buckets.map(&:total)).to eq([ 7, 64, 8, 0 ])
  end

  it "stacks each bucket by repo and holds its entries" do
    may = tally("year").buckets.find { |bucket| bucket.span.monday == Date.new(2026, 5, 4) }

    expect(may.span.monday).to eq(Date.new(2026, 5, 4))
    expect(may.total).to eq(55)
    expect(may.counts).to eq(progress_repo(0) => 35, progress_repo(3) => 20)
    expect(may.items.map(&:title)).to eq([ "First user signed up 🥳🥳🥳", "story time is live! 🚀🚀🚀", "Share on 𝕏 !" ])
  end

  it "counts only the selected project's commits and tagged entries under a filter" do
    trained_on = tally("year", repo: progress_repo(4))

    expect(trained_on.items.map(&:title)).to eq([ "Trained on me is live!!" ])
    expect(trained_on.totals.counts.keys).to eq([ progress_repo(4) ])
    expect(trained_on.totals.share).to eq((100.0 * trained_on.totals.commits / 380).round)
    expect(trained_on.first_active_day).to eq(Date.new(2026, 9, 24))
  end

  it "ranks projects by all-time commits" do
    expect(tally("week").projects.all.map(&:name))
      .to eq(%w[openstage wheels-off goal_atlas story_time_v1 trained-on watchtower trained-on-dataset])
  end

  it "leaves out private entries, hidden ones and tooling noise" do
    create(:entry, user: user, repo_name: progress_repo(0), title: "Merge pull request #4 from me/x", occurred_at: 1.hour.ago)
    create(:entry, user: user, repo_name: progress_repo(0), visibility: :private_entry, occurred_at: 1.hour.ago)
    create(:entry, user: user, repo_name: progress_repo(0), hidden: true, occurred_at: 1.hour.ago)

    expect(tally("week").totals.commits).to eq(79)
  end

  it "counts an entry logged as Shipped as shipped, not as a commit" do
    create(:entry, user: user, source: "manual", title: "Launched on Product Hunt", occurred_at: 1.hour.ago)
    week = tally("week")

    expect(week.items.map { |item| [ item.title, item.shipped? ] }).to eq([ [ "Launched on Product Hunt", true ] ])
    expect(numbers(week.totals).first(3)).to eq([ 1, 0, 79 ])
  end

  it "counts days in the builder's zone" do
    create(:entry, user: user, repo_name: progress_repo(0), occurred_at: Time.utc(2026, 10, 14, 23, 30))
    expect(tally("week").buckets.map(&:total)[2, 2]).to eq([ 9, 0 ])

    user.update!(time_zone: "Europe/Lisbon")
    expect(tally("week").buckets.map(&:total)[2, 2]).to eq([ 8, 1 ])
  end

  # Ranked or not, a tally starts where the same work began: one takes it
  # from the reads that rank the projects, the other from a MIN of its own.
  it "starts a page's window past a project's hidden commits, and the emails' period at them, as the emails still count them" do
    quiet = create(:user)
    create(:github_repo, user: quiet, full_name: "quiet/hush", name: "hush", hidden_numbers: [ "commits" ])
    create(:entry, user: quiet, repo_name: "quiet/hush", occurred_at: Time.utc(2025, 3, 3))
    create(:entry, user: quiet, repo_name: "quiet/loud", occurred_at: Time.utc(2026, 10, 13))

    firsts = [ false, true ].map do |ranked|
      page = described_class.new(user: quiet, range: "all", rolling: true, ranked: ranked).tap(&:call!)
      email = described_class.new(user: quiet, range: "all", ranked: ranked).tap(&:call!)
      [ page.period.first_activity, email.period.first_activity ]
    end

    expect(firsts).to eq([ [ Date.new(2026, 10, 13), Date.new(2025, 3, 3) ] ] * 2)
  end

  it "starts a page's window at the first commit or entry in view: one with no project, or an entry before its project's commits" do
    quiet = create(:user)
    create(:entry, user: quiet, occurred_at: Time.utc(2026, 2, 3))
    create(:entry, user: quiet, repo_name: "quiet/app", occurred_at: Time.utc(2026, 5, 1))
    create(:entry, user: quiet, source: "manual", entry_type: "milestone", title: "Began", repo_name: "quiet/app", occurred_at: Time.utc(2026, 4, 1))
    first = lambda do |repos, ranked|
      described_class.new(user: quiet, range: "all", rolling: true, repos: repos, ranked: ranked).tap(&:call!).period.first_activity
    end

    expect([ false, true ].map { |ranked| [ first.call([], ranked), first.call([ "quiet/app" ], ranked) ] })
      .to eq([ [ Date.new(2026, 2, 3), Date.new(2026, 4, 1) ] ] * 2)
  end

  it "reads the commits a page's chart also counts with its own, in one statement, and keeps its numbers to the period" do
    plain = described_class.new(user: user, range: "30d", rolling: true).tap(&:call!)
    counting = described_class::Counting.new(from: Date.new(2026, 1, 1), repos: nil)
    reads = 0
    counter = ->(*, payload) { reads += 1 if payload[:sql].include?("DATE((entries.occurred_at") }

    page = ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      described_class.new(user: user, range: "30d", rolling: true, counting: counting).tap(&:call!)
    end

    expect(reads).to eq(1)
    expect([ page.totals, page.previous_totals, page.buckets, page.day_counts ]).to eq([ plain.totals, plain.previous_totals, plain.buckets, plain.day_counts ])
    expect(page.commit_days).to include(plain.commit_days)
    expect(page.commit_days.keys.map(&:first).min).to be < plain.commit_days.keys.map(&:first).min
  end

  it "reads for a project's page the earlier commits of that project alone" do
    quiet = create(:user)
    create(:github_repo, user: quiet, full_name: "quiet/hush", name: "hush", hidden_numbers: [ "commits" ])
    create(:entry, user: quiet, repo_name: "quiet/hush", occurred_at: Time.utc(2026, 3, 3))
    create(:entry, user: quiet, repo_name: "quiet/loud", occurred_at: Time.utc(2026, 3, 4))
    create(:entry, user: quiet, source: "manual", entry_type: "milestone", title: "Live", repo_name: "quiet/hush", occurred_at: Time.utc(2026, 10, 13))
    page = lambda do |counting|
      described_class.new(user: quiet, range: "12m", rolling: true, repos: [ "quiet/hush" ], counting: counting).tap(&:call!)
    end

    counted = page.call(described_class::Counting.new(from: Date.new(2025, 10, 1), repos: [ "quiet/hush" ]))

    expect(counted.commit_days).to eq([ Date.new(2026, 3, 3), "quiet/hush" ] => 1)
    expect(page.call(nil).commit_days).to eq({})
  end

  it "counts several projects together" do
    both = tally("year", repo: [ progress_repo(0), progress_repo(1) ])

    expect(both.totals.commits).to eq(176 + 62)
    expect(both.totals.counts.keys).to contain_exactly(progress_repo(0), progress_repo(1))
  end
end
