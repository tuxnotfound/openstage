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
      expect(forms.map { |form| form.at_css("input[name=github]")["id"] }).to eq(%w[preview-login preview-login-end])
      expect(response.body).not_to include("Start free with GitHub")
    end

    # The preview is the one main action; whoever is ready signs in from a
    # link under it, the header's button too, and reads what that asks. A
    # live stage is the demo card's own link.
    it "puts the box first, then the sign-in as a link, then what the sign-in asks" do
      Rails.configuration.x.github_profile_token = "preview-token"
      get "/"
      Rails.configuration.x.github_profile_token = nil

      page = Nokogiri::HTML(response.body)
      hero = page.at_css("main section")
      expect(hero.css("form").map { |form| form["action"] }).to eq(%w[/preview /auth/github])
      expect([ hero.at_css("form button").text, hero.at_css("form button")["class"] ]).to eq([ "Preview your stage", "os-btn" ])
      # "No sign-in" sits under the button, inside the form.
      expect(hero.at_css("form[data-preview-form] button + p.os-note").text).to eq("No sign-in needed to preview.")
      # On a wide screen the sign-in link shares the second row with the demo
      # card's "View this stage" (home_layout_spec).
      expect(hero.at_css("form[action='/auth/github']")["class"]).to include("lg:row-start-2")
      expect(hero.at_css("input[name=github]")["placeholder"]).to eq("tuxnotfound")
      expect(hero.at_css("form[data-preview-form] label").text.squish).to eq("Your GitHub username github.com/")
      sign_in = hero.at_css("form[action='/auth/github'] button")
      expect([ sign_in.text.squish, sign_in["class"] ]).to eq([ "Or sign in with GitHub and skip the preview.", "os-link cursor-pointer text-[15px]" ])
      expect(hero.css("p.os-note").map(&:text)).to match([ "No sign-in needed to preview.", a_string_starting_with("Asks only for your email.") ])
      expect(hero.css("a").map { |link| link.text.squish }).not_to include("See a live stage", "See a live stage →")
      expect(page.at_css("header form[action='/auth/github'] button.os-btn").text).to eq("Make your own stage")
    end

    # The header has scrolled away by the landing's end, so the sign-in link
    # is there again, under the box.
    it "ends on the box and the sign-in link" do
      Rails.configuration.x.github_profile_token = "preview-token"
      get "/"
      Rails.configuration.x.github_profile_token = nil

      last = Nokogiri::HTML(response.body).css("main section").last
      expect(last.css("form").map { |form| form["action"] }).to eq(%w[/preview /auth/github])
      expect(last.at_css("form[action='/auth/github'] button").text.squish).to eq("Or sign in with GitHub and skip the preview.")
      expect(last.css("p.os-note").map(&:text)).to eq([ "No sign-in needed to preview." ])
    end

    it "keeps the sign-in while previews are off, as before the token is set" do
      get "/"

      page = Nokogiri::HTML(response.body)
      expect(response.body).not_to include("data-preview-form")
      sections = [ page.at_css("main section"), page.css("main section").last ]
      expect(sections.map { |section| section.at_css("form[action='/auth/github'] button")&.[]("class") }).to eq(%w[os-btn os-btn])
      expect(sections.first.at_css("p.os-note").text).to start_with("Asks only for your email.")
    end

    it "shows a member their dashboard, with nothing about signing in" do
      sign_in_as(create(:user))
      get "/"

      hero = Nokogiri::HTML(response.body).at_css("main section")
      expect(hero.css("a.os-btn").map { |link| [ link.text, link["href"] ] }).to eq([ [ "Go to your dashboard", "/dashboard" ] ])
      expect(hero.css("form, p.os-note")).to be_empty
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
