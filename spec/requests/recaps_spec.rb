require "rails_helper"

RSpec.describe "Recaps", type: :request do
  let(:owner) { create(:user, github_username: "tuxnotfound", username: "tuxnotfound") }

  def commit(title, repo: "tuxnotfound/openstage", sha: nil, at: 1.day.ago)
    create(:entry, user: owner, entry_type: "shipped", source: "github", title: title,
                   repo_name: repo, external_id: sha || "sha-#{title.parameterize}", occurred_at: at)
  end

  describe "GET /recap" do
    context "when not the owner" do
      it "404s when signed out" do
        get "/recap"
        expect(response).to have_http_status(:not_found)
      end

      it "404s for another signed-in user" do
        sign_in_as(create(:user, github_username: "someone_else"))
        get "/recap"
        expect(response).to have_http_status(:not_found)
      end

      it "does not advertise the page in the nav" do
        sign_in_as(create(:user, github_username: "someone_else", username: "someone"))
        get "/dashboard"
        expect(response.body).not_to include(">Recap<")
      end
    end

    context "as the owner" do
      before { sign_in_as(owner) }

      it "links the page from the nav" do
        get "/dashboard"
        expect(response.body).to include(">Recap<")
        expect(response.body).to include('href="/recap"')
      end

      it "renders the quiet-week state when there is nothing worth posting" do
        commit("a lone commit")

        get "/recap"
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Quiet week")
      end

      context "with a real week" do
        before do
          create(:entry, user: owner, entry_type: "milestone", source: "manual",
                         title: "Rebirth begins", occurred_at: 1.day.ago)
          commit("fix sync on default branch switch")
          commit("add overlap window to since")
          commit("derive final standings", repo: "tuxnotfound/goal_atlas")
          commit("Merge branch 'main' into feature")
        end

        it "shows the skeleton and every non-tooling commit as a candidate" do
          get "/recap"

          expect(response.body).to include("Rebirth begins")
          expect(response.body).to include("fix sync on default branch switch")
          expect(response.body).to include("derive final standings")
          expect(response.body).not_to include("Merge branch &#39;main&#39; into feature")
        end

        it "reveals tooling commits behind the toggle" do
          get "/recap", params: { noise: "1" }

          expect(response.body).to include("Merge branch &#39;main&#39; into feature")
        end

        it "composes only what was picked" do
          get "/recap", params: { picks: [ 1 ] }

          expect(response.body).to include("fix sync on default branch switch")
          expect(response.body).to include("Copy")
        end

        it "honours the window selector" do
          commit("something older", at: 40.days.ago)

          get "/recap", params: { days: "90" }
          expect(response.body).to include("something older")

          get "/recap", params: { days: "7" }
          expect(response.body).not_to include("something older")
        end

        it "falls back to 7 days for an unsupported window" do
          get "/recap", params: { days: "365" }
          expect(response.body).to include("7 days")
        end
      end
    end
  end

  describe "POST /recap/posted" do
    before { sign_in_as(owner) }

    it "logs a Posted entry from a pasted URL" do
      expect {
        post "/recap/posted", params: { url: "https://x.com/tuxnotfound/status/123", text: "Shipped this week:\n- a thing" }
      }.to change { owner.entries.where(entry_type: "posted").count }.by(1)

      entry = owner.entries.find_by(entry_type: "posted")
      expect(entry.url).to eq("https://x.com/tuxnotfound/status/123")
      expect(entry.title).to eq("Shipped this week:")
      expect(entry.source).to eq("manual")
    end

    it "refuses to log without a URL, so nothing unverifiable is recorded" do
      expect {
        post "/recap/posted", params: { url: "  ", text: "Shipped this week:" }
      }.not_to change { Entry.count }

      expect(flash[:alert]).to match(/Paste the URL/)
    end

    it "404s for a non-owner" do
      sign_in_as(create(:user, github_username: "someone_else"))
      post "/recap/posted", params: { url: "https://x.com/a/1" }

      expect(response).to have_http_status(:not_found)
    end
  end
end
