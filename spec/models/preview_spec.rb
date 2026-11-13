require "rails_helper"
require "support/github_profile"

RSpec.describe Preview do
  include GithubProfileData

  let(:today) { Date.new(2026, 11, 12) }

  def preview(repos, latest: [])
    described_class.new(profile: github_profile(repos: repos), latest: latest, today: today)
  end

  it "reads from the cards' first week, which starts before the 12 months" do
    expect(described_class.first_day(today)).to eq(Date.new(2025, 11, 17))
  end

  it "ranks the projects by commits over the 12 months, leaving out older work" do
    result = preview([
      github_profile_repo(name: "small", days: { today - 5 => 2 }),
      github_profile_repo(name: "big", days: { today - 5 => 3, today - 40 => 4 }),
      github_profile_repo(name: "before", days: { Date.new(2025, 11, 20) => 8 })
    ])

    expect(result.projects.map { |project| [ project.name, project.commits, project.rank ] }).to eq([ [ "big", 7, 0 ], [ "small", 2, 1 ] ])
    expect(result.commits).to eq(9)
  end

  it "gives a card to the projects with a colour and lists the rest" do
    repos = Array.new(ProgressChart::Palette::SIZE + 2) { |i| github_profile_repo(name: "p#{i}", days: { today - 1 => 30 - i }) }
    result = preview(repos)

    expect(result.cards.map(&:name)).to eq(repos.first(ProgressChart::Palette::SIZE).map(&:name))
    expect(result.rest.map(&:name)).to eq(%w[p10 p11])
  end

  # The line runs 52 weeks, from 2025-11-17; the count is the 12 months the
  # headline sums, from 2025-12-01, so the cards add up to it.
  it "draws a card's 52 weeks, this week last, and counts the headline's 12 months" do
    result = preview([ github_profile_repo(days: { today => 2, today - 7 => 3, Date.new(2025, 11, 17) => 1 }) ])
    card = result.cards.first

    expect(card.weeks.size).to eq(52)
    expect(card.weeks.last(2)).to eq([ 3, 2 ])
    expect(card.weeks.first).to eq(1)
    expect(card).to have_attributes(commits: 5, last_commit: today, description: "The analytical engine")
    expect(result.cards.sum(&:commits)).to eq(result.commits)
  end

  it "draws its chart with the code that draws a stage's" do
    result = preview([ github_profile_repo(name: "engine", days: { today - 5 => 3, Date.new(2026, 3, 10) => 5 }),
                       github_profile_repo(name: "notes", days: { today - 1 => 1 }) ])
    chart = ProgressChart::Trend.new(result.section)

    expect(chart.lines.map { |line| [ line.name, line.total ] }).to eq([ [ "engine", 8 ], [ "notes", 1 ] ])
    expect(chart.lines.first.values.sum).to eq(8)
    expect(chart.paths.size).to eq(2)
    expect(chart.axis.last).to eq("Today")
  end

  it "groups the latest commits by project and day, newest first, for projects on the preview" do
    result = preview([ github_profile_repo(name: "engine", days: { today - 1 => 2 }) ], latest: [
      github_profile_commit(title: "Second", at: Time.utc(2026, 11, 11, 15)),
      github_profile_commit(title: "First", at: Time.utc(2026, 11, 11, 9)),
      github_profile_commit(title: "Older", at: Time.utc(2026, 11, 2, 9)),
      github_profile_commit(repo: "ada/elsewhere", title: "Not here", at: Time.utc(2026, 11, 1, 9))
    ])

    expect(result.recent.map { |group| [ group.project.name, group.date, group.commits.map(&:title) ] }).to eq([
      [ "engine", Date.new(2026, 11, 11), %w[Second First] ],
      [ "engine", Date.new(2026, 11, 2), %w[Older] ]
    ])
  end
end
