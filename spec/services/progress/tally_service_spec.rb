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

  it "starts a page's window past a project's hidden commits, and the emails' period at them, as the emails still count them" do
    quiet = create(:user)
    create(:github_repo, user: quiet, full_name: "quiet/hush", name: "hush", hidden_numbers: [ "commits" ])
    create(:entry, user: quiet, repo_name: "quiet/hush", occurred_at: Time.utc(2025, 3, 3))
    create(:entry, user: quiet, repo_name: "quiet/loud", occurred_at: Time.utc(2026, 10, 13))

    page = described_class.new(user: quiet, range: "all", rolling: true).tap(&:call!)
    email = described_class.new(user: quiet, range: "all").tap(&:call!)

    expect([ page.period.first_activity, email.period.first_activity ]).to eq([ Date.new(2026, 10, 13), Date.new(2025, 3, 3) ])
  end

  it "counts several projects together" do
    both = tally("year", repo: [ progress_repo(0), progress_repo(1) ])

    expect(both.totals.commits).to eq(176 + 62)
    expect(both.totals.counts.keys).to contain_exactly(progress_repo(0), progress_repo(1))
  end
end
