require "rails_helper"

RSpec.describe Progress::CountService do
  let(:user) { create(:user, time_zone: "Europe/Paris") }
  let(:repo) { create(:github_repo, user: user, full_name: "me/app", homepage: "https://app.example", site_source: "script") }

  before { travel_to Time.utc(2026, 10, 28, 12) }

  def counts(**options)
    described_class.new(user: user, commit_repos: [ "me/app" ], visit_repos: [ repo ], commit_days: {}, first_commits: {}, **options)
                   .tap(&:call!).counts
  end

  it "counts the commits of the projects that count from the first day needed, and the first day each had one, in the builder's zone" do
    days = { [ Date.new(2026, 9, 30), "me/app" ] => 2, [ Date.new(2026, 10, 27), "me/app" ] => 1,
             [ Date.new(2026, 10, 27), "me/other" ] => 4, [ Date.new(2026, 10, 27), nil ] => 3 }
    firsts = { "me/app" => Time.utc(2026, 1, 4, 23, 30), "me/other" => Time.utc(2025, 1, 1), nil => Time.utc(2024, 1, 1) }

    counted = counts(commit_days: days, first_commits: firsts, from: Date.new(2026, 10, 1))

    expect(counted.sum("commits", "me/app")).to eq(1)
    expect(counted.sum("commits", "me/app", Date.new(2026, 10, 27)..Date.new(2026, 10, 27))).to eq(1)
    expect(counted.first_day("commits", [ "me/app" ])).to eq(Date.new(2026, 1, 5))
    expect([ counted.sum("commits", "me/other"), counted.first_day("commits", [ "me/other" ]) ]).to eq([ 0, nil ])
    expect(counts(commit_days: days, first_commits: firsts).sum("commits", "me/app")).to eq(3)
  end

  it "counts the visits to each project's website, and the first day one came" do
    repo.site_visit_days.create!(day: Date.new(2026, 10, 27), visits: 40, visitors: 12)
    repo.site_visit_days.create!(day: Date.new(2026, 9, 1), visits: 3, visitors: 1)

    counted = counts(from: Date.new(2026, 10, 1))

    expect(counted.sum("visits", "me/app")).to eq(40)
    expect(counted.first_day("visits", [ "me/app" ])).to eq(Date.new(2026, 9, 1))
  end

  it "counts the visitors to each project's website over any days, and the first day one came, with the visits in one read each" do
    other = create(:github_repo, user: user, full_name: "me/other", homepage: "https://other.example", site_source: "script")
    repo.site_visit_days.create!(day: Date.new(2026, 10, 3), visits: 9, visitors: 0)
    repo.site_visit_days.create!(day: Date.new(2026, 10, 5), visits: 40, visitors: 12)
    repo.site_visit_days.create!(day: Date.new(2026, 10, 20), visits: 7, visitors: 5)
    other.site_visit_days.create!(day: Date.new(2026, 10, 6), visits: 4, visitors: 3)
    reads = []
    counter = ->(*, payload) { reads << payload[:sql] if payload[:sql].include?("site_visit_days") }

    counted = ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { counts(from: Date.new(2026, 10, 1), visit_repos: [ repo, other ]) }

    expect(reads.size).to eq(2)
    expect([ counted.sum("site_visitors", "me/app"), counted.sum("site_visitors", "me/other") ]).to eq([ 17, 3 ])
    expect(counted.sum("site_visitors", "me/app", Date.new(2026, 10, 4)..Date.new(2026, 10, 19))).to eq(12)
    expect([ counted.first_day("site_visitors", [ "me/app" ]), counted.first_day("visits", [ "me/app" ]) ]).to eq([ Date.new(2026, 10, 5), Date.new(2026, 10, 3) ])
    expect(counted.first_day("site_visitors", [ "me/app", "me/other" ])).to eq(Date.new(2026, 10, 5))
  end

  it "needs a builder" do
    expect(described_class.new(commit_repos: [ "me/app" ]).call).to be(false)
  end
end
