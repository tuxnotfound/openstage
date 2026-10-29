require "rails_helper"

RSpec.describe "Feed", type: :request do
  describe "GET /feed" do
    it "is public, so it is a real discovery surface for crawlers and visitors" do
      builder = create(:user, username: "builder")
      create(:entry, user: builder, title: "shipped something public")

      get "/feed"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("shipped something public")
    end

    it "puts one builder's day in one card, the three newest and how many more" do
      builder = create(:user, username: "builder")
      day = 1.day.ago.beginning_of_day + 10.hours
      5.times { |i| create(:entry, user: builder, title: "Step #{i}", repo_name: "builder/app", occurred_at: day + i.minutes) }
      create(:entry, user: builder, title: "Earlier work", repo_name: "builder/app", occurred_at: day - 2.days)

      get "/feed"

      cards = Nokogiri::HTML(response.body).css("#feed-groups article").map { |card| card.text.squish }
      expect(cards.size).to eq(2)
      expect(cards.first).to include("@builder", "5 commits · yesterday", "Step 4", "Step 2", "and 2 more that day")
      expect(cards.first).not_to include("Step 1")
    end

    it "leaves out merges, dependency bumps and the owner's own work, so it shows the others" do
      builder = create(:user, username: "builder")
      owner = create(:user, username: "tuxnotfound", github_username: "tuxnotfound")
      create(:entry, user: builder, title: "Merge pull request #3 from builder/branch")
      create(:entry, user: builder, title: "Bump rack from 3.0 to 3.1")
      create(:entry, user: builder, title: "Add the login page")
      create(:entry, user: owner, title: "The owner's own commit")

      get "/feed"

      expect(response.body).to include("Add the login page")
      expect(response.body).not_to include("Merge pull request", "Bump rack", "The owner's own commit")
    end

    it "leaves out the commits of a project whose builder hides them, from its entries and its day's count, keeping its milestones" do
      builder = create(:user, username: "builder")
      create(:github_repo, user: builder, full_name: "builder/app", hidden_numbers: [ "commits" ])
      day = 1.day.ago.beginning_of_day + 10.hours
      2.times { |i| create(:entry, user: builder, title: "Hidden step #{i}", repo_name: "builder/app", occurred_at: day + i.minutes) }
      create(:entry, user: builder, title: "Shown step", repo_name: "builder/site", occurred_at: day + 5.minutes)
      create(:entry, user: builder, entry_type: "milestone", source: "manual", title: "Launched app", repo_name: "builder/app", occurred_at: day + 6.minutes)

      get "/feed"

      cards = Nokogiri::HTML(response.body).css("#feed-groups article").map { |card| card.text.squish }
      expect(cards).to eq([ cards.first ])
      expect(cards.first).to include("1 commit · 1 shipped · yesterday", "Launched app", "Shown step")
      expect(response.body).not_to include("Hidden step")
    end

    it "shows only what shipped, or only posts, and never a commit under either" do
      builder = create(:user, username: "builder")
      create(:entry, user: builder, title: "A commit")
      create(:entry, user: builder, entry_type: "milestone", source: "manual", title: "A launch")
      create(:entry, user: builder, entry_type: "posted", source: "manual", title: "A post")

      get "/feed", params: { show: "shipped" }
      expect(response.body).to include("A launch")
      expect(response.body).not_to include("A post", "A commit")

      get "/feed", params: { show: "posts" }
      expect(response.body).to include("A post")
      expect(response.body).not_to include("A launch")
    end

    it "is in the header for everyone, lit while it is shown" do
      get "/pricing"
      expect(response.body[/<nav class="os-nav.*?<\/nav>/m]).to include(%(<a href="/feed">Feed</a>))

      sign_in_as(create(:user, username: "builder"))
      get "/feed"
      expect(response.body[/<nav class="os-nav.*?<\/nav>/m]).to include(%(<a aria-current="page" href="/feed">Feed</a>))
    end

    it "is linked from every public profile" do
      create(:user, username: "someone")

      get "/someone"
      expect(response.body).to include('href="/feed"')
      expect(response.body).to include("Explore other builders")
    end
  end

  describe "the free-tier footer" do
    it "sits at the end of the page, not above the profile header" do
      create(:user, username: "freebie")

      get "/freebie"
      expect(response.body.index("data-claim-cta")).to be > response.body.index('aria-label="Profile"')
    end

    it "carries a ref tag so footer-driven signups are attributable" do
      create(:user, username: "freebie2")

      get "/freebie2"
      expect(response.body).to include("?ref=footer")
    end

    it "stays hidden for Pro profiles" do
      create(:user, username: "paid", pro: true)

      get "/paid"
      expect(response.body).not_to include("data-claim-cta")
      expect(response.body).to include("Explore other builders")
    end
  end
end
