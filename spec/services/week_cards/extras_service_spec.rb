require "rails_helper"

RSpec.describe WeekCards::ExtrasService do
  let(:user) { create(:user, github_username: "tux") }
  let(:monday) { Date.new(2026, 10, 5) }
  let(:week_card) { WeekCard.new(user: user, week_start: monday) }

  def commit(at, **attrs)
    create(:entry, user: user, source: "github", entry_type: "shipped", repo_name: "tux/app", occurred_at: at, **attrs)
  end

  def extras(commits = user.entries.to_a)
    described_class.new(week_card: week_card, commits: commits).tap(&:call!).extras
  end

  describe "building" do
    it "counts weeks from the date the builder set, to the card's Sunday" do
      user.update!(building_since: Date.new(2026, 3, 23))

      expect(extras.building).to have_attributes(since: Date.new(2026, 3, 23), week: 29)
    end

    it "falls back to the builder's first public entry" do
      commit(Time.utc(2026, 9, 30, 12))
      commit(Time.utc(2026, 1, 2, 12), hidden: true)

      expect(extras.building.since).to eq(Date.new(2026, 9, 30))
    end

    it "is nothing before the builder started" do
      user.update!(building_since: Date.new(2026, 11, 1))

      expect(extras.building).to be_nil
    end
  end

  describe "audience" do
    it "counts unique visitors this week and last, and confirmed subscribers this week" do
      2.times { create(:profile_view, user: user, ip_hash: "a", viewed_at: Time.utc(2026, 10, 6, 12)) }
      create(:profile_view, user: user, ip_hash: "b", viewed_at: Time.utc(2026, 10, 7, 12))
      create(:profile_view, user: user, ip_hash: "c", viewed_at: Time.utc(2026, 9, 30, 12))
      Subscription.create!(user: user, email: "a@example.com", confirmed_at: Time.utc(2026, 10, 8, 12))
      Subscription.create!(user: user, email: "b@example.com")

      expect(extras.audience).to have_attributes(visitors: 2, visitors_before: 1, subscribers: 1)
    end

    it "is nothing in a week nobody came" do
      expect(extras.audience).to be_nil
    end
  end

  describe "hours" do
    it "tallies commits by hour in the card's zone and finds the busiest two hours" do
      week_card.time_zone = "Europe/Lisbon"
      [ 18, 18, 19, 9 ].each { |hour| commit(Time.utc(2026, 10, 6, hour)) }

      hours = extras.hours
      expect(hours.counts[19]).to eq(2)
      expect(hours.counts[10]).to eq(1)
      expect(hours).to have_attributes(peak_from: 19, peak_to: 21)
    end

    it "is nothing without commits" do
      expect(extras([]).hours).to be_nil
    end
  end

  describe "code" do
    it "adds up lines over the commits GitHub has measured, with each language's share" do
      commit(Time.utc(2026, 10, 6), additions: 90, deletions: 10, files_changed: 3, languages: { "Ruby" => 75, "CSS" => 25 },
                                    stats_fetched_at: Time.current)
      commit(Time.utc(2026, 10, 7), additions: 10, deletions: 0, files_changed: 1, languages: { "Ruby" => 0 },
                                    stats_fetched_at: Time.current)
      commit(Time.utc(2026, 10, 8))

      expect(extras.code).to have_attributes(additions: 100, deletions: 10, files: 4, languages: [ [ "Ruby", 75 ], [ "CSS", 25 ] ])
    end

    it "is nothing until GitHub has measured a commit" do
      commit(Time.utc(2026, 10, 6))

      expect(extras.code).to be_nil
    end
  end

  describe "repos" do
    let(:repo) { create(:github_repo, user: user, full_name: "tux/app") }

    def activity(kind, at, on: repo)
      GithubActivity.create!(user: user, github_repo: on, kind: kind, external_id: GithubActivity.count + 1, occurred_at: at)
    end

    it "counts the week's releases and the stars it brought" do
      create(:entry, user: user, source: "github", entry_type: "released", title: "app v1", occurred_at: Time.utc(2026, 10, 8))
      GithubRepoStarCount.create!(github_repo: repo, recorded_on: Date.new(2026, 10, 1), stars: 10)
      GithubRepoStarCount.create!(github_repo: repo, recorded_on: Date.new(2026, 10, 9), stars: 14)
      GithubRepoStarCount.create!(github_repo: repo, recorded_on: Date.new(2026, 10, 13), stars: 20)

      expect(extras.repos).to have_attributes(merged_prs: 0, releases: 1, deploys: 0, stars: 4)
    end

    it "counts the week's merged pull requests and deploys on included repos" do
      hidden = create(:github_repo, user: user, full_name: "tux/hidden", included: false)
      2.times { activity("pull_request", Time.utc(2026, 10, 6, 12)) }
      activity("pull_request", Time.utc(2026, 10, 4, 12))
      activity("pull_request", Time.utc(2026, 10, 7, 12), on: hidden)
      3.times { activity("deployment", Time.utc(2026, 10, 11, 12)) }
      activity("deployment", Time.utc(2026, 10, 12, 12))

      expect(extras.repos).to have_attributes(merged_prs: 2, releases: 0, deploys: 3, stars: 0)
    end

    it "counts from the first snapshot for a repo first seen this week" do
      GithubRepoStarCount.create!(github_repo: repo, recorded_on: Date.new(2026, 10, 6), stars: 3)
      GithubRepoStarCount.create!(github_repo: repo, recorded_on: Date.new(2026, 10, 10), stars: 5)

      expect(extras.repos.stars).to eq(2)
    end

    it "is nothing in a week GitHub counted nothing" do
      GithubRepoStarCount.create!(github_repo: repo, recorded_on: Date.new(2026, 10, 6), stars: 3)
      activity("deployment", Time.utc(2026, 9, 30, 12))
      activity("pull_request", Time.utc(2026, 10, 6, 12), on: create(:github_repo, user: user, included: false))

      expect(extras.repos).to be_nil
    end
  end
end
