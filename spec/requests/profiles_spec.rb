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
    end

    context "filtering by project (the whole story)" do
      let!(:user) { create(:user, username: "builder") }
      let!(:shipped) { create(:entry, user: user, entry_type: "shipped", source: "github", repo_name: "builder/openstage", occurred_at: 2.days.ago) }
      let!(:note)    { create(:entry, user: user, entry_type: "note",    source: "manual", repo_name: "builder/openstage", occurred_at: 1.day.ago) }
      let!(:other)   { create(:entry, user: user, entry_type: "note",    source: "manual", repo_name: "builder/other",     occurred_at: 1.day.ago) }

      it "shows both shipped and manual entries for a project" do
        get "/builder", params: { repo: "builder/openstage" }
        expect(response.body).to include(shipped.title)
        expect(response.body).to include(note.title)
        expect(response.body).not_to include(other.title)
      end
    end
  end
end
