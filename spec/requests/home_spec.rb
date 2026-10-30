require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "returns http success" do
      get "/"
      expect(response).to have_http_status(:success)
    end

    it "leads with the friction, not a feature list" do
      get "/"

      expect(response.body).to include("Keep shipping.")
      expect(response.body).to include("Openstage does the showing.")
      expect(response.body).to include("Start free with GitHub")
    end

    # The whole feed left the landing on 2026-09-29, when it sold a network of
    # a handful of people. One entry at a time shows the product in use.
    it "shows other builders' latest work one entry at a time, three at most from any builder" do
      owner = create(:user, username: "tuxnotfound", github_username: "tuxnotfound")
      create(:entry, user: owner, title: "The owner's own commit", occurred_at: 1.minute.ago)
      alice = create(:user, username: "alice")
      4.times { |i| create(:entry, user: alice, title: "Alice step #{i}", repo_name: "alice/app", occurred_at: (i + 1).hours.ago) }
      create(:entry, user: alice, title: "Merge pull request #3 from alice/x", occurred_at: 10.minutes.ago)
      bob = create(:user, username: "bob")
      create(:entry, user: bob, entry_type: "milestone", source: "manual", title: "Bob's launch", occurred_at: 5.hours.ago)

      get "/"

      lately = Nokogiri::HTML(response.body).at_css("section[aria-labelledby='lately']")
      items = lately.css("[data-rotate-target='item']")
      expect(items.map { |item| item.at_css(".font-semibold").text }).to eq([ "Alice step 0", "Alice step 1", "Alice step 2", "Bob's launch" ])
      expect(items.map { |item| item["href"] }).to eq(%w[/alice/app /alice/app /alice/app /bob])
      expect(items.map { |item| item["inert"].present? }).to eq([ false, true, true, true ])
      expect(lately.text).not_to include("owner's own", "Merge pull request")
    end

    it "leaves out of the strip the commits of a project whose builder hides them, keeping its milestones" do
      alice = create(:user, username: "alice")
      create(:github_repo, user: alice, full_name: "alice/app", hidden_numbers: [ "commits" ])
      create(:entry, user: alice, title: "Alice's hidden commit", repo_name: "alice/app", occurred_at: 1.hour.ago)
      create(:entry, user: alice, entry_type: "milestone", source: "manual", title: "Alice's launch", repo_name: "alice/app", occurred_at: 2.hours.ago)

      get "/"

      lately = Nokogiri::HTML(response.body).at_css("section[aria-labelledby='lately']")
      expect(lately.css("[data-rotate-target='item'] .font-semibold").map(&:text)).to eq([ "Alice's launch" ])
    end

    it "leaves the strip out while nobody else has public work" do
      get "/"

      expect(response.body).not_to include("Lately on Openstage")
    end

    it "counts no commit of a project whose builder hides them in the demo's number, share bar or chart" do
      demo = create(:user, username: "tuxnotfound")
      create(:github_repo, user: demo, full_name: "tuxnotfound/app", name: "app", hidden_numbers: [ "commits" ])
      2.times { create(:entry, user: demo, repo_name: "tuxnotfound/app", occurred_at: 2.days.ago) }
      create(:entry, user: demo, repo_name: "tuxnotfound/site", occurred_at: 2.days.ago)

      get "/"

      page = Nokogiri::HTML(response.body)
      expect(response.body).to match(%r{<span class="os-num[^"]*">1</span>\s*<span[^>]*>commits, last 12 months})
      expect(page.css("[aria-label='Share of commits by project'] > div").map { |part| part["title"] }).to eq([ "site: 1 commit" ])
      expect(page.css(".os-chart svg path").size).to eq(1)
    end

    it "counts the demo page's public commits, the ones its builder hid from the lists too" do
      demo = create(:user, username: "tuxnotfound")
      create(:github_repo, user: demo, full_name: "tuxnotfound/app")
      create(:entry, user: demo, repo_name: "tuxnotfound/app")
      create(:entry, user: demo, repo_name: "tuxnotfound/app", hidden: true)
      create(:entry, user: demo, repo_name: "tuxnotfound/app", visibility: "private")

      get "/"

      expect(response.body).to match(%r{<span class="os-num[^"]*">2</span>\s*<span[^>]*>commits, last 12 months})
    end
  end
end
