require "rails_helper"

RSpec.describe Progress::CountService do
  let(:user) { create(:user, time_zone: "Europe/Paris") }
  let(:repo) { create(:github_repo, user: user, full_name: "me/app", homepage: "https://app.example", site_source: "script") }

  before { travel_to Time.utc(2026, 10, 28, 12) }

  def counts(**options)
    described_class.new(user: user, commit_repos: [ "me/app" ], visit_repos: [ repo ], first_commits: {}, **options).tap(&:call!).counts
  end

  it "counts each project's public commits per day in the builder's zone, and the first day it had one, in that zone" do
    create(:entry, user: user, repo_name: "me/app", occurred_at: Time.utc(2026, 10, 26, 23, 30))
    create(:entry, user: user, repo_name: "me/app", occurred_at: Time.utc(2026, 1, 5, 12))
    create(:entry, user: user, repo_name: "me/app", occurred_at: 1.day.ago, hidden: true)
    create(:entry, user: user, repo_name: "me/other", occurred_at: 1.day.ago)
    firsts = { "me/app" => Time.utc(2026, 1, 4, 23, 30), "me/other" => Time.utc(2025, 1, 1), nil => Time.utc(2024, 1, 1) }

    counted = counts(from: Date.new(2026, 10, 1), first_commits: firsts)

    expect(counted.sum("commits", "me/app")).to eq(1)
    expect(counted.sum("commits", "me/app", Date.new(2026, 10, 27)..Date.new(2026, 10, 27))).to eq(1)
    expect(counted.first_day("commits", [ "me/app" ])).to eq(Date.new(2026, 1, 5))
    expect([ counted.sum("commits", "me/other"), counted.first_day("commits", [ "me/other" ]) ]).to eq([ 0, nil ])
    expect(counts.sum("commits", "me/app")).to eq(2)
  end

  it "counts the visits to each project's website, and the first day one came" do
    repo.site_visit_days.create!(day: Date.new(2026, 10, 27), visits: 40, visitors: 12)
    repo.site_visit_days.create!(day: Date.new(2026, 9, 1), visits: 3, visitors: 1)

    counted = counts(from: Date.new(2026, 10, 1))

    expect(counted.sum("visits", "me/app")).to eq(40)
    expect(counted.first_day("visits", [ "me/app" ])).to eq(Date.new(2026, 9, 1))
  end

  it "needs a builder" do
    expect(described_class.new(commit_repos: [ "me/app" ]).call).to be(false)
  end
end
