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

      it "shows Powered by Openstage footer for free profiles" do
        get "/testuser"
        expect(response.body).to include("Powered by Openstage")
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

      it "hides the Posted filter tab when the user has no posted entries" do
        create(:entry, user: user, entry_type: "shipped")
        get "/testuser"
        expect(response.body).to include(">Shipped</a>")
        expect(response.body).not_to include(">Posted</a>")
      end

      it "shows the Posted filter tab once the user has a posted entry" do
        create(:entry, user: user, entry_type: "posted", source: "manual")
        get "/testuser"
        expect(response.body).to include(">Posted</a>")
      end
    end

    context "when user is pro" do
      let!(:user) { create(:user, username: "paidbuilder", pro: true) }

      it "does not show Powered by Openstage footer" do
        get "/paidbuilder"
        expect(response.body).not_to include("Powered by Openstage")
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

    context "timeline filtering" do
      let!(:user) { create(:user, username: "builder") }
      let!(:shipped_entry)   { create(:entry, user: user, entry_type: "shipped",   source: "github", occurred_at: 3.days.ago) }
      let!(:milestone_entry) { create(:entry, user: user, entry_type: "milestone", source: "manual", occurred_at: 2.days.ago) }
      let!(:note_entry)      { create(:entry, user: user, entry_type: "note",      source: "manual", occurred_at: 1.day.ago) }

      it "shows all entries with no filter" do
        get "/builder"
        expect(response.body).to include(shipped_entry.title)
        expect(response.body).to include(milestone_entry.title)
        expect(response.body).to include(note_entry.title)
      end

      it "shows only shipped entries when filter=shipped" do
        get "/builder", params: { filter: "shipped" }
        expect(response.body).to include(shipped_entry.title)
        expect(response.body).not_to include(milestone_entry.title)
        expect(response.body).not_to include(note_entry.title)
      end

      it "shows only milestone entries when filter=milestone" do
        get "/builder", params: { filter: "milestone" }
        expect(response.body).to include(milestone_entry.title)
        expect(response.body).not_to include(shipped_entry.title)
      end

      it "falls back to all entries for an invalid filter" do
        get "/builder", params: { filter: "invalid_type" }
        expect(response.body).to include(shipped_entry.title)
        expect(response.body).to include(milestone_entry.title)
      end

      it "does not show hidden entries" do
        hidden = create(:entry, user: user, entry_type: "note", source: "manual", hidden: true, occurred_at: Time.current)
        get "/builder"
        expect(response.body).not_to include(hidden.title)
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

    context "pagination" do
      let!(:user) { create(:user, username: "prolific") }

      it "shows a load more button when there are more than 25 entries" do
        create_list(:entry, 26, user: user, entry_type: "shipped", source: "github", occurred_at: Time.current)
        get "/prolific"
        expect(response.body).to include("Load more")
      end

      it "does not show a load more button when there are 25 or fewer entries" do
        create_list(:entry, 5, user: user, entry_type: "shipped", source: "github", occurred_at: Time.current)
        get "/prolific"
        expect(response.body).not_to include("Load more")
      end
    end
  end
end
