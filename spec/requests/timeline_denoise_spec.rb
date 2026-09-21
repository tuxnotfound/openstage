require "rails_helper"

RSpec.describe "Public timeline de-noising", type: :request do
  let(:user) { create(:user, username: "builder") }

  def commit(title, at:, repo: "builder/app", **attrs)
    create(:entry, user: user, entry_type: "shipped", source: "github", title: title, repo_name: repo,
                   external_id: SecureRandom.hex(6), occurred_at: at, **attrs)
  end

  describe "tooling noise" do
    titles = {
      "Merge pull request #12 from a/b"        => true,
      "Merge branch 'main' into feature"       => true,
      "chore(deps): bump rack from 3.0 to 3.1" => true,
      "Bump nokogiri from 1.15.0 to 1.16.0"    => true,
      "Update dependencies"                    => true,
      "[dependabot] weekly"                    => true,
      "Bump version to 1.2.0"                  => false,
      "Revert \"Add admin page\""              => false,
      "Merge sort for the timeline"            => false,
      "fix git sync job"                       => false
    }

    it "agrees with the recap's filter on every shape, so the two never drift" do
      titles.each_key { |t| commit(t, at: 1.day.ago) }
      kept = user.entries.without_tooling_noise.pluck(:title)

      titles.each do |title, noise|
        expect(RecapDraft::NOISE.match?(title)).to eq(noise), "recap disagrees on #{title}"
        expect(kept.include?(title)).to eq(!noise), "timeline disagrees on #{title}"
      end
    end

    it "never hides something a person typed, whatever it says" do
      create(:entry, user: user, entry_type: "note", source: "manual", title: "Merge branch thoughts", occurred_at: 1.day.ago)

      get "/builder"
      expect(response.body).to include("Merge branch thoughts")
    end

    it "drops bot commits from the public list" do
      commit("Bump rack from 3.0 to 3.1", at: 1.day.ago)
      commit("Add the admin page", at: 1.day.ago)

      get "/builder"
      expect(response.body).to include("Add the admin page")
      expect(response.body).not_to include("Bump rack")
    end
  end

  describe "work sessions" do
    it "folds a day of commits to one repo into one card that still lists every commit" do
      day = 2.days.ago.beginning_of_day + 10.hours
      5.times { |i| commit("Step #{i}", at: day + i.minutes) }

      get "/builder"

      expect(response.body).to include('data-session-size="5"')
      expect(response.body).to include("5 commits")
      5.times { |i| expect(response.body).to include("Step #{i}") }
      expect(response.body).to include("2 more commits that day")
    end

    it "leaves one or two commits as ordinary entries" do
      commit("Lonely one", at: 2.days.ago)
      commit("Lonely two", at: 2.days.ago)

      get "/builder"
      expect(response.body).not_to include("data-session-size")
    end

    it "does not fold across repos, days, or a milestone in between" do
      day = 3.days.ago.beginning_of_day + 10.hours
      commit("A1", at: day, repo: "builder/a")
      commit("A2", at: day + 1.minute, repo: "builder/a")
      commit("B1", at: day + 2.minutes, repo: "builder/b")
      commit("A3", at: day + 3.minutes, repo: "builder/a")

      get "/builder"
      expect(response.body).not_to include("data-session-size")
    end

    it "keeps each commit's anchor so old deep links still land" do
      day = 2.days.ago.beginning_of_day + 10.hours
      entries = 3.times.map { |i| commit("Anchored #{i}", at: day + i.minutes) }

      get "/builder"
      entries.each { |e| expect(response.body).to include(%(id="entry-#{e.id}")) }
    end
  end
end
