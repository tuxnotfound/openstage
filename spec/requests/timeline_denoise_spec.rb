require "rails_helper"

RSpec.describe "Public page de-noising", type: :request do
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

  describe "branch commits" do
    it "shows a commit not yet on the default branch with its branch" do
      commit("Try a new layout", at: 1.day.ago, branch: "redesign/layout")

      get "/builder"

      expect(recent.text.squish).to include("Try a new layout on redesign/layout")
    end

    it "hides them once the builder turns branch commits off" do
      commit("Try a new layout", at: 1.day.ago, branch: "layout")
      user.update!(branch_commits: false)

      get "/builder"

      expect(response.body).not_to include("Try a new layout")
    end
  end

  describe "recent commits" do
    it "puts a day of commits to one project in one row, the three newest and how many more" do
      day = 2.days.ago.beginning_of_day + 10.hours
      5.times { |i| commit("Step #{i}", at: day + i.minutes) }

      get "/builder"

      expect(recent.css(".os-row").size).to eq(1)
      expect(recent.text.squish).to include("app #{day.strftime('%b %-d')} · 5 commits Step 4 Step 3 Step 2 and 2 more")
      expect(recent.text).not_to include("Step 1")
    end

    it "keeps projects and days apart, newest first" do
      day = 3.days.ago.beginning_of_day + 10.hours
      commit("A1", at: day, repo: "builder/a")
      commit("B1", at: day + 2.minutes, repo: "builder/b")
      commit("A2", at: day + 1.day, repo: "builder/a")

      get "/builder"

      expect(recent.css(".os-row").map { |row| row.at_css(".font-bold").text.squish }).to eq(%w[a b a])
    end

    it "shows at most eight rows" do
      9.times { |i| commit("Day #{i}", at: (i + 1).days.ago) }

      get "/builder"

      expect(recent.css(".os-row").size).to eq(8)
      expect(recent.text).not_to include("Day 8")
    end

    it "keeps each shown commit's anchor so deep links still land" do
      entries = 3.times.map { |i| commit("Anchored #{i}", at: 2.days.ago + i.minutes) }

      get "/builder"
      entries.each { |e| expect(response.body).to include(%(id="entry-#{e.id}")) }
    end
  end

  def recent
    Nokogiri::HTML(response.body).at_css("section[aria-labelledby='recent-commits']")
  end
end

RSpec.describe "Distribution surfaces", type: :request do
  let!(:user) { create(:user, username: "builder") }

  it "gives a visitor to a free profile their next action, tagged" do
    get "/builder"
    expect(response.body).to include("data-claim-cta")
    expect(response.body).to include("?ref=footer")
  end

  it "does not show the claim link to the owner or on Pro pages" do
    sign_in_as(user)
    get "/builder"
    expect(response.body).not_to include("data-claim-cta")

    reset!
    user.update!(pro: true)
    get "/builder"
    expect(response.body).not_to include("data-claim-cta")
  end

  it "nudges the badge on the dashboard until one has rendered somewhere" do
    sign_in_as(user)
    get "/dashboard"
    expect(response.body).to include("data-badge-nudge")
    expect(response.body).to include("/builder?ref=badge")

    user.badge_impressions.create!(kind: "badge", viewed_at: Time.current)
    get "/dashboard"
    expect(response.body).not_to include("data-badge-nudge")
  end
end
