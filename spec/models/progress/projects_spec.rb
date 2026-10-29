require "rails_helper"

RSpec.describe Progress::Projects do
  let(:user) { create(:user) }

  def projects
    described_class.new(user.entries.publicly_visible.without_tooling_noise)
  end

  it "ranks repos by all-time commits, then tagged-only repos by name" do
    2.times { create(:entry, user: user, repo_name: "me/b") }
    create(:entry, user: user, repo_name: "me/a")
    create(:entry, user: user, source: "manual", entry_type: "milestone", repo_name: "me/z")

    expect(projects.all.map { |project| [ project.name, project.commits, project.rank ] }).to eq([ [ "b", 2, 0 ], [ "a", 1, 1 ], [ "z", 0, 2 ] ])
  end

  it "keeps the owner in the name when two repos share one" do
    create(:entry, user: user, repo_name: "me/app")
    create(:entry, user: user, repo_name: "team/app")
    create(:entry, user: user, repo_name: "me/site")

    expect(projects.all.map(&:name)).to eq(%w[me/app site team/app])
    expect(projects.find("me/site").name).to eq("site")
  end

  it "says when each project's commits and entries began, the ones with no project under nil, in the reads that rank them" do
    create(:github_repo, user: user, full_name: "me/quiet", name: "quiet", hidden_numbers: [ "commits" ])
    create(:entry, user: user, repo_name: "me/b", occurred_at: Time.utc(2026, 3, 1))
    create(:entry, user: user, repo_name: "me/b", occurred_at: Time.utc(2026, 2, 1))
    create(:entry, user: user, repo_name: "me/quiet", occurred_at: Time.utc(2025, 5, 1))
    create(:entry, user: user, occurred_at: Time.utc(2025, 6, 1))
    create(:entry, user: user, source: "manual", entry_type: "milestone", repo_name: "me/z", occurred_at: Time.utc(2024, 1, 1))
    create(:entry, user: user, source: "manual", entry_type: "note", occurred_at: Time.utc(2024, 2, 1))
    listed = projects
    reads = 0
    counter = ->(*, payload) { reads += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { [ listed.all, listed.first_commits, listed.first_highlights ] }

    expect(listed.first_commits).to eq("me/b" => Time.utc(2026, 2, 1), "me/quiet" => Time.utc(2025, 5, 1), nil => Time.utc(2025, 6, 1))
    expect(listed.first_commits(shown: true)).to eq("me/b" => Time.utc(2026, 2, 1), nil => Time.utc(2025, 6, 1))
    expect(listed.first_highlights).to eq("me/z" => Time.utc(2024, 1, 1), nil => Time.utc(2024, 2, 1))
    expect(reads).to eq(2)
  end
end
