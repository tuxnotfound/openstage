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
    end

    # Signing in claims a stage the visitor has already seen, so the landing
    # asks for a GitHub username first, at its top and its end.
    it "asks a signed-out visitor for their GitHub username, not a sign-in" do
      Rails.configuration.x.github_profile_token = "preview-token"
      get "/"
      Rails.configuration.x.github_profile_token = nil

      forms = Nokogiri::HTML(response.body).css("form[data-preview-form]")
      expect(forms.map { |form| form["action"] }).to eq(%w[/preview /preview])
      expect(forms.map { |form| form.at_css("input[name=login]")["id"] }).to eq(%w[preview-login preview-login-end])
      expect(response.body).not_to include("Start free with GitHub")
    end

    it "keeps the sign-in while previews are off, as before the token is set" do
      get "/"

      expect(response.body).not_to include("data-preview-form")
      expect(Nokogiri::HTML(response.body).css("form[action='/auth/github']").size).to be >= 2
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
      expect(response.body).to match(%r{<span class="os-num[^"]*">1</span>\s*<span[^>]*>commits, last 30 days})
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

      expect(response.body).to match(%r{<span class="os-num[^"]*">2</span>\s*<span[^>]*>commits, last 30 days})
    end
  end
end
