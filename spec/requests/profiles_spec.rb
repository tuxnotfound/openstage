require "rails_helper"

RSpec.describe "Profiles", type: :request do
  describe "GET /:username" do
    context "when user exists" do
      let!(:user) { create(:user, username: "testuser") }

      it "returns http success" do
        get "/testuser"
        expect(response).to have_http_status(:success)
      end

      it "does not show README badge snippet" do
        get "/testuser"
        expect(response.body).not_to include("README badge")
        expect(response.body).not_to include("/badge/testuser.svg")
      end

      it "shows the claim link in the footer of free profiles" do
        get "/testuser"
        expect(response.body).to include("Get your own proof-of-work page")
      end

      it "marks the GitHub account with GitHub's icon and says so to screen readers" do
        get "/testuser"

        github = Nokogiri::HTML(response.body).at_css("a[href='https://github.com/#{user.github_username}']")
        expect(github.at_css("svg[aria-hidden='true']")).to be_present
        expect(github.text.squish).to eq("GitHub #{user.github_username}")
      end

      it "shows the builder's X account and email only once each is turned on" do
        user.update!(email: "me@example.com", x_username: "tux404")
        get "/testuser"
        expect(response.body).not_to include("x.com/tux404", "me@example.com")

        user.update!(show_email: true, show_x_username: true)
        get "/testuser"
        page = Nokogiri::HTML(response.body)
        expect(page.at_css("a[href='https://x.com/tux404']").text.squish).to eq("X @tux404")
        expect(page.at_css("a[href='mailto:me@example.com']").text.squish).to eq("Email me@example.com")
      end

      it "never renders a javascript: website URL into the page" do
        user.update_column(:website_url, "javascript:alert(document.cookie)")

        get "/testuser"
        expect(response.body).not_to include("javascript:alert")
      end

      it "records a profile view for a real browser" do
        expect {
          get "/testuser", headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }
        }.to change { user.profile_views.count }.by(1)
      end

      it "does not record a profile view for a crawler" do
        expect {
          get "/testuser", headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (compatible; ClaudeBot/1.0; +claudebot@anthropic.com)" }
        }.not_to change { user.profile_views.count }
      end
    end

    context "when user is pro" do
      let!(:user) { create(:user, username: "paidbuilder", pro: true) }

      it "does not show Powered by Openstage footer" do
        get "/paidbuilder"
        expect(response.body).not_to include("data-claim-cta")
      end
    end

    context "when user does not exist" do
      it "shows the claim page" do
        get "/nobody_here_xyz"
        expect(response).to have_http_status(:success)
        expect(response.body).to include("@nobody_here_xyz isn't on Openstage yet")
        expect(response.body).to include("@nobody_here_xyz is available")
      end
    end

    context "what shipped" do
      let!(:user) { create(:user, username: "builder") }
      let!(:commit)    { create(:entry, user: user, repo_name: "builder/app", occurred_at: 3.days.ago) }
      let!(:milestone) { create(:entry, user: user, entry_type: "milestone", source: "manual", occurred_at: 2.days.ago) }
      let!(:note)      { create(:entry, user: user, entry_type: "note", source: "manual", occurred_at: 1.day.ago) }

      def shipped
        Nokogiri::HTML(response.body).at_css("section[aria-labelledby='what-shipped']")
      end

      it "lists what shipped and was published in the window, newest first, and no commit" do
        get "/builder"

        rows = shipped.css(".os-row").map { |row| row.text.squish }
        expect(rows.size).to eq(2)
        expect(rows.first).to include("Published", note.title)
        expect(rows.last).to include("Shipped", milestone.title)
        expect(shipped.text).not_to include(commit.title)
        expect(shipped.text.squish).to include("2 in the last 12 months")
      end

      it "does not show hidden entries" do
        hidden = create(:entry, user: user, entry_type: "note", source: "manual", hidden: true, occurred_at: Time.current)
        get "/builder"
        expect(response.body).not_to include(hidden.title)
      end

      it "sends a link through the click counter, in a new tab" do
        linked = create(:entry, user: user, entry_type: "link", source: "manual", url: "https://example.com/post", occurred_at: 1.hour.ago)

        get "/builder"

        link = shipped.at_css("a[href='/e/#{linked.id}/out']")
        expect(link["target"]).to eq("_blank")
        expect(link["data-turbo"]).to eq("false")
      end

      it "folds everything after the eighth behind Show all" do
        8.times { |i| create(:entry, user: user, entry_type: "note", source: "manual", occurred_at: (i + 3).days.ago) }

        get "/builder"

        expect(shipped.at_css("details summary").text).to eq("Show all 10")
        expect(shipped.css("details .os-row").size).to eq(2)
      end
    end

    context "its entries and streak" do
      let!(:user) { create(:user, username: "builder") }

      before do
        2.times { |i| create(:entry, user: user, repo_name: "builder/app", occurred_at: (i + 1).days.ago) }
        create(:entry, user: user, repo_name: "builder/app", entry_type: "milestone", source: "manual", occurred_at: Time.current)
      end

      def facts
        Nokogiri::HTML(response.body).at_css("section[aria-label='Profile'] p.os-xs").text.squish
      end

      def description
        Nokogiri::HTML(response.body).at_css("meta[name='description']")["content"]
      end

      it "counts no commit of a project whose builder hides them, in either" do
        get "/builder"
        expect(facts).to include("3 entries", "3-day streak")
        expect(description).to include("3 entries")

        create(:github_repo, user: user, full_name: "builder/app", hidden_numbers: [ "commits" ])
        get "/builder"

        expect(facts).to include("1 entry", "1-day streak")
        expect(description).to include("1 entries")
      end

      it "keeps the page of a builder whose public work is all hidden commits, its project and its chart, and counts none" do
        user.entries.where(source: "manual").destroy_all
        create(:github_repo, user: user, full_name: "builder/app", hidden_numbers: [ "commits" ])

        get "/builder"

        expect(facts).to include("0 entries")
        expect(response.body).not_to include("Nothing here yet")
        expect(Nokogiri::HTML(response.body).at_css("[data-react='progress']")).to be_present
        expect(Nokogiri::HTML(response.body).css("section[aria-labelledby='projects'] .os-h3").map { |name| name.text.squish }).to eq([ "app" ])
      end
    end

    context "a link to one entry" do
      let!(:user) { create(:user, username: "builder") }
      let!(:old) { create(:entry, user: user, repo_name: "builder/app", title: "An old commit", occurred_at: 40.days.ago) }

      before { 9.times { |i| create(:entry, user: user, repo_name: "builder/app", occurred_at: (i + 1).days.ago) } }

      def linked
        Nokogiri::HTML(response.body).at_css("[data-linked-entry]")
      end

      it "shows the entry at the top, holding its anchor once, wherever the page would put it" do
        get "/builder", params: { entry: old.id }

        expect(linked["id"]).to eq("entry-#{old.id}")
        expect(linked.text.squish).to include("The entry you followed", "An old commit", "Commit")
        expect(response.body.scan(%(id="entry-#{old.id}")).size).to eq(1)

        recent = user.entries.order(occurred_at: :desc).first
        get "/builder", params: { entry: recent.id }
        expect(response.body.scan(%(id="entry-#{recent.id}")).size).to eq(1)
        expect(linked["id"]).to eq("entry-#{recent.id}")
      end

      it "shows nothing for a commit of a project whose builder hides them, and still shows its milestone" do
        launch = create(:entry, user: user, repo_name: "builder/app", entry_type: "milestone", source: "manual", title: "Launched app", occurred_at: 50.days.ago)
        get "/builder", params: { entry: old.id }
        expect(linked).to be_present

        create(:github_repo, user: user, full_name: "builder/app", hidden_numbers: [ "commits" ])
        get "/builder", params: { entry: old.id }
        expect(linked).to be_nil
        expect(response.body).not_to include("An old commit")

        get "/builder", params: { entry: launch.id }
        expect(linked.text.squish).to include("Launched app")
      end

      it "shows nothing for an entry that is hidden, private or someone else's" do
        hidden = create(:entry, user: user, hidden: true)
        private_note = create(:entry, user: user, entry_type: "note", source: "manual", visibility: :private_entry)
        theirs = create(:entry, user: create(:user))

        [ hidden, private_note, theirs ].each do |entry|
          get "/builder", params: { entry: entry.id }
          expect(linked).to be_nil
        end
      end
    end

    context "projects" do
      let!(:user) { create(:user, username: "builder") }

      before do
        create(:github_repo, user: user, full_name: "builder/app", description: "A tool for builders.")
        create(:github_repo, user: user, full_name: "builder/secret", private_repo: true)
        2.times { |i| create(:entry, user: user, repo_name: "builder/app", occurred_at: (i + 1).days.ago) }
        create(:entry, user: user, repo_name: "builder/secret", occurred_at: 3.days.ago)
      end

      def cards
        Nokogiri::HTML(response.body).css("section[aria-labelledby='projects'] .os-card").map { |card| card.text.squish }
      end

      it "gives each project a card with GitHub's description and its last 12 months" do
        get "/builder"

        expect(cards.first).to include("app", "public repo", "A tool for builders.", "2 commits in 12 months · last commit yesterday")
        expect(cards.last).to include("secret", "private repo, commit messages only", "1 commit in 12 months · last commit 3 days ago")
      end

      it "leaves a project's commits off its card when its builder hides them" do
        user.github_repos.find_by(full_name: "builder/app").update!(hidden_numbers: [ "commits" ])

        get "/builder"

        app = Nokogiri::HTML(response.body).css("section[aria-labelledby='projects'] .os-card").first
        expect(app.text.squish).to include("app", "A tool for builders.", "Project page")
        expect(app.text).not_to include("commit")
        expect(app.at_css("svg path")).to be_nil
        expect(cards.last).to include("1 commit in 12 months · last commit 3 days ago")
        expect(response.body).to include("Commits per week over the last 12 months")
      end

      it "gives the card of a project ranked eleventh no dot and its chart in ink, and the chart above no box or line for it" do
        8.times { |i| create(:entry, user: user, repo_name: "builder/p#{i}", occurred_at: 2.days.ago) }
        create(:entry, user: user, repo_name: "builder/zz", occurred_at: 2.days.ago)

        get "/builder"

        page = Nokogiri::HTML(response.body)
        all = page.css("section[aria-labelledby='projects'] .os-card")
        card = all.find { |each| each.at_css(".os-h3").text.squish == "zz" }
        expect(card["class"].split).to include("os-project-none")
        expect([ card.at_css(".os-dot"), card.css("svg path").size ]).to eq([ nil, 2 ])
        expect(all.count { |each| each.at_css(".os-h3 .os-dot") }).to eq(10)
        expect(page.at_css("[data-chart-row='builder/zz'] a")).to be_nil
        expect(page.at_css("[data-chart-row='builder/zz']").text.squish).to eq("zz, draws no line Commits 1")
        expect(page.at_css("[data-chart-row='builder/zz'] .sr-only").text).to eq(", draws no line")
        expect(page.css("svg path[data-number='commits']").size).to eq(10)
      end

      it "lists no commit of a project whose builder hides them under Recent commits, and keeps its milestones" do
        create(:entry, user: user, repo_name: "builder/app", title: "Fix the login", occurred_at: 1.hour.ago)
        create(:entry, user: user, repo_name: "builder/app", entry_type: "milestone", source: "manual", title: "Launched app", occurred_at: 2.hours.ago)
        user.github_repos.find_by(full_name: "builder/app").update!(hidden_numbers: [ "commits" ])

        get "/builder"

        recent = Nokogiri::HTML(response.body).at_css("section[aria-labelledby='recent-commits']").text.squish
        expect(recent).to include("secret", "1 commit")
        expect(recent).not_to include("app", "Fix the login")
        expect(response.body).not_to include("Fix the login")
        expect(response.body).to include("Launched app")
      end

      it "says nothing of weekly commits when no card shows them" do
        user.github_repos.each { |repo| repo.update!(hidden_numbers: [ "commits" ]) }

        get "/builder"

        expect(response.body).not_to include("Commits per week over the last 12 months")
      end

      it "opens a project's page from its name, never filtering the chart above" do
        get "/builder"

        name = Nokogiri::HTML(response.body).at_css("section[aria-labelledby='projects'] .os-card .os-h3")
        expect(name["href"]).to eq("/builder/app")
        expect(name["data-turbo-frame"]).to eq("_top")
      end

      it "shows a project's own words and status, as the builder and GitHub set them, and leaves its picture to its page" do
        user.github_repos.find_by(full_name: "builder/app")
            .update!(description_edit: "My words.", homepage: "https://app.example", archived: true,
                     preview_image_url: "https://repository-images.githubusercontent.com/1/x")

        get "/builder"

        card = Nokogiri::HTML(response.body).at_css("section[aria-labelledby='projects'] .os-card")
        expect(card.text.squish).to include("app Live Archived", "My words.", "app.example")
        expect(card.at_css("img")).to be_nil
        expect(card.at_css("a[href='https://app.example']")["target"]).to eq("_blank")
      end
    end

    context "filtering by project (the whole story)" do
      let!(:user) { create(:user, username: "builder") }
      let!(:shipped) { create(:entry, user: user, entry_type: "shipped", source: "github", repo_name: "builder/openstage", occurred_at: 2.days.ago) }
      let!(:note)    { create(:entry, user: user, entry_type: "note",    source: "manual", repo_name: "builder/openstage", occurred_at: 1.day.ago) }
      let!(:other)   { create(:entry, user: user, entry_type: "note",    source: "manual", repo_name: "builder/other",     occurred_at: 1.day.ago) }

      # The page's JSON carries every project, so its script can switch
      # without a request; what shows is the project picked.
      it "shows both shipped and manual entries for a project" do
        get "/builder", params: { repo: "builder/openstage" }
        shown = Nokogiri::HTML(response.body)
        shown.css("script").remove
        expect(shown.text).to include(shipped.title, note.title)
        expect(shown.text).not_to include(other.title)
      end
    end
  end
end
