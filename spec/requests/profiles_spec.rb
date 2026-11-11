require "rails_helper"

RSpec.describe "Profiles", type: :request do
  describe "GET /:username" do
    context "when user exists" do
      let!(:user) { create(:user, username: "testuser") }

      it "returns http success" do
        get "/testuser"
        expect(response).to have_http_status(:success)
      end

      it "stays out of search until the builder has a public entry" do
        create(:entry, user: user, source: "manual", entry_type: "note", visibility: :private_entry)
        get "/testuser"
        expect(response.body).to include(%(<meta name="robots" content="noindex">))

        create(:entry, user: user, source: "manual", entry_type: "note")
        get "/testuser"
        expect(response.body).not_to include(%(name="robots"))
      end

      it "counts one of each in the singular in the description of a builder with no bio" do
        create(:entry, user: user, entry_type: "milestone", source: "manual")
        create(:github_repo, user: user)
        get "/testuser"

        description = Nokogiri::HTML(response.body).at_css("meta[name='description']")["content"]
        expect(description).to end_with("1 entry, 1 repo, 1 milestone.")
      end

      it "does not show README badge snippet" do
        get "/testuser"
        expect(response.body).not_to include("README badge")
        expect(response.body).not_to include("/badge/testuser.svg")
      end

      it "ends a free profile on the header's button, tagged footer" do
        get "/testuser"
        expect(Nokogiri::HTML(response.body).at_css("footer #{"input[name='ref'][value='footer']"}")).to be_present
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

      it "asks search engines not to count the links the builder types as votes: their website and each project's" do
        user.update!(website_url: "https://me.example")
        create(:github_repo, user: user, full_name: "testuser/sauna", homepage: "https://sauna.example")
        create(:entry, user: user, repo_name: "testuser/sauna")

        get "/testuser"

        page = Nokogiri::HTML(response.body)
        expect(%w[https://me.example https://sauna.example].map { |site| page.at_css("a[href='#{site}']")["rel"] }).to eq([ "ugc nofollow noopener" ] * 2)
      end

      it "never renders a javascript: website URL into the page" do
        user.update_column(:website_url, "javascript:alert(document.cookie)")

        get "/testuser"
        expect(response.body).not_to include("javascript:alert")
      end

      def view_ticket_in(body)
        Nokogiri::HTML(body).at_css("[data-controller='page-view']")&.[]("data-page-view-ticket-value")
      end

      it "counts a real browser's view once the page sends it back, with where the visitor came from" do
        browser = { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                    "HTTP_REFERER" => "https://news.ycombinator.com/item?id=1" }

        expect { get "/testuser", headers: browser }.not_to change { user.profile_views.count }
        expect { post "/pv", params: { t: view_ticket_in(response.body) }, headers: browser }.to change { user.profile_views.count }.by(1)
        expect(user.profile_views.last.referrer).to eq("news.ycombinator.com")
      end

      it "hands a crawler no ticket, so its visit never counts" do
        get "/testuser", headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (compatible; ClaudeBot/1.0; +claudebot@anthropic.com)" }

        expect(view_ticket_in(response.body)).to be_nil
      end

      it "hands the builder no ticket on their own page" do
        sign_in_as(user)
        get "/testuser"

        expect(view_ticket_in(response.body)).to be_nil
      end

      it "counts no view for a read of the feed" do
        expect { get "/testuser.rss" }.not_to change { user.profile_views.count }
      end

      # A page Turbo loaded as the pointer rested on a link to it is a full
      # render nobody may open.
      it "tells Turbo never to load a page ahead, so a view counts only when the page opens" do
        get "/testuser"

        expect(Nokogiri::HTML(response.body).at_css("head meta[name='turbo-prefetch']")["content"]).to eq("false")
      end
    end

    context "when user is pro" do
      let!(:user) { create(:user, username: "paidbuilder", pro: true) }

      it "does not end on the button to make your own stage" do
        get "/paidbuilder"
        expect(Nokogiri::HTML(response.body).at_css("footer input[name='ref'][value='footer']")).to be_nil
      end
    end

    context "when user does not exist" do
      it "shows the claim page, as a 404 so search indexes no made-up name" do
        get "/nobody_here_xyz"
        expect(response).to have_http_status(:not_found)
        expect(response.body).to include("@nobody_here_xyz isn't on Openstage yet")
        expect(response.body).to include("@nobody_here_xyz is available")
      end
    end

    context "what's new" do
      let!(:user) { create(:user, username: "builder") }
      let!(:commit)    { create(:entry, user: user, repo_name: "builder/app", occurred_at: 3.days.ago) }
      let!(:milestone) { create(:entry, user: user, entry_type: "milestone", source: "manual", occurred_at: 2.days.ago) }
      let!(:note)      { create(:entry, user: user, entry_type: "note", source: "manual", occurred_at: 1.day.ago) }

      def shipped
        Nokogiri::HTML(response.body).at_css("section[aria-labelledby='whats-new']")
      end

      it "lists what shipped and was published in the window, newest first, and no commit" do
        get "/builder"

        rows = shipped.css(".os-row").map { |row| row.text.squish }
        expect(rows.size).to eq(2)
        expect(rows.first).to include("Published", note.title)
        expect(rows.last).to include("Milestone", milestone.title)
        expect(shipped.text).not_to include(commit.title)
        expect(shipped.text.squish).to include("2 in the last 30 days")
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

      it "marks each on the chart, a link to its row in What's new, and no commit" do
        get "/builder"

        page = Nokogiri::HTML(response.body)
        links = page.css(".os-chart a[href^='#entry-']")
        expect(links.map { |link| link["href"] }).to contain_exactly("#entry-#{milestone.id}", "#entry-#{note.id}")
        expect(links.map { |link| link["aria-label"] }).to contain_exactly(start_with("Milestone: #{milestone.title}, "), start_with("Published: #{note.title}, "))
        expect(links.map { |link| shipped.at_css(link["href"])&.text&.squish }).to all(be_present)
      end

      it "folds everything after the eighth behind Show all" do
        8.times { |i| create(:entry, user: user, entry_type: "note", source: "manual", occurred_at: (i + 3).days.ago) }

        get "/builder"

        expect(shipped.at_css("details[class~='group/all'] > summary").text).to eq("Show all 10")
        expect(shipped.css("details[class~='group/all'] > .os-row").size).to eq(2)
      end

      it "wears each entry's mark, opens a row on its description, the newest open, and keeps its title's link outside the toggle" do
        milestone.update!(body: "What it took.")
        linked = create(:entry, user: user, entry_type: "posted", source: "manual", title: "How I built it", body: "The long story.",
                                url: "https://example.com/story", occurred_at: 1.hour.ago)

        get "/builder"

        rows = shipped.css(".os-row")
        expect(rows.map { |row| [ row.name, row["open"], row.at_css("svg path[fill-rule='evenodd']")&.[]("d")&.slice(0, 6) ] })
          .to eq([ [ "details", "open", "M3.5 2" ], [ "div", nil, "M3.5 2" ], [ "details", nil, "M3 1.5" ] ])
        expect(rows.first.at_css("summary a[href='/e/#{linked.id}/out']")).to be_present
        expect(rows.first.at_css("p").text).to eq("The long story.")
        expect(rows.map { |row| row.at_css(".os-xs").text.squish }).to eq(%w[Published Published Milestone])
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
        expect(description).to include("1 entry,")
      end

      it "keeps the page of a builder whose public work is all hidden commits, its project and its chart, and counts none" do
        user.entries.where(source: "manual").destroy_all
        create(:github_repo, user: user, full_name: "builder/app", hidden_numbers: [ "commits" ])

        get "/builder"

        expect(facts).not_to include("entries", "entry", "milestone")
        expect(description).to eq("#{user.display_name} is building in public on Openstage — 1 repo.")
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

    context "a builder with more projects than colours" do
      let!(:user) { create(:user, username: "builder") }

      before do
        10.times { |i| 3.times { create(:entry, user: user, repo_name: "builder/top#{i}", occurred_at: 1.day.ago) } }
        create(:github_repo, user: user, full_name: "builder/sauna", homepage: "https://sauna.example")
        create(:entry, user: user, repo_name: "builder/sauna", occurred_at: 2.days.ago)
        create(:entry, user: user, repo_name: "builder/fire", occurred_at: 9.days.ago)
      end

      def page
        Nokogiri::HTML(response.body)
      end

      def list
        page.at_css("#more-projects")
      end

      def listed
        list.css("a[data-turbo-frame='_top']").map(&:text)
      end

      it "gives the ten with a colour a card and a row in the chart's table, and lists the rest under the cards" do
        get "/builder"

        expect(page.css("section[aria-labelledby='projects'] .os-card").size).to eq(10)
        expect(page.css("section[aria-labelledby='projects'] .os-card .os-h3 .os-dot").size).to eq(10)
        expect(page.css("[data-chart-row]").size).to eq(10)
        expect(page.css("svg path[data-number='commits']").size).to eq(10)
        expect(page.at_css("[data-chart-table] a[href='#more-projects']").text.squish).to eq("2 more projects ↓")
        expect(list.at_css("h3").text).to eq("2 more projects")
        expect(listed).to eq(%w[sauna fire])
        expect(list.text.squish).to include("sauna Live", "1 commit in 12 months", "Last commit 2 days ago", "1–2 of 2")
        expect(list.at_css("a[href='/builder/sauna']")["data-turbo-frame"]).to eq("_top")
        expect(list.at_css("[data-react='projects']")).to be_present
      end

      it "opens the list on another view without its script, keeping the chart's window" do
        get "/builder", params: { range: "90d" }

        by_name = list.css(".os-pills a").find { |link| link.text == "A–Z" }
        expect(by_name["href"]).to eq("/builder?range=90d&sort=name#more-projects")
        expect([ list.at_css("a.os-chip").text, list.at_css("a.os-chip")["href"] ]).to eq([ "Live · 1", "/builder?live=1&range=90d#more-projects" ])
        expect(list.css("form[role='search'] input[type='hidden']").to_h { |input| [ input["name"], input["value"] ] }).to eq("range" => "90d")

        get "/builder", params: { range: "90d", sort: "name" }
        expect(listed).to eq(%w[fire sauna])
        expect(list.at_css(".os-pills a[aria-current='true']").text).to eq("A–Z")

        get "/builder", params: { q: "kale" }
        expect(listed).to eq([])
        expect(list.text).to include(%(No project named "kale".))
      end

      it "keeps the list off the page of a builder with ten projects or fewer" do
        user.entries.where(repo_name: %w[builder/sauna builder/fire]).delete_all

        get "/builder"

        expect(list).to be_nil
        expect(page.at_css("[data-chart-table] a[href='#more-projects']")).to be_nil
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
