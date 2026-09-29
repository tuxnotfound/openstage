require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  describe "GET /dashboard" do
    context "when not signed in" do
      it "redirects to root" do
        get "/dashboard"
        expect(response).to redirect_to(root_path)
      end
    end

    context "when signed in" do
      let(:user) { create(:user, username: "builder") }

      before { sign_in_as(user) }

      it "shows the badge as an onboarding step, not the Settings snippet block" do
        get "/dashboard"

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include("README badge")
        expect(response.body).to include("data-badge-nudge")
      end

      it "keeps the page one glance away: its link, a copy button and sync status" do
        get "/dashboard"

        card = response.body[/<section[^>]*data-page-card.*?<\/section>/m]
        expect(card).to include("openstage.dev/builder")
        expect(card).to include("Copy link")
        expect(card).to include("Sync now")
      end

      it "points a quiet week at the composer instead of the recap" do
        get "/dashboard"

        expect(response.body).to include("Quiet week so far.")
        expect(response.body).to include("Add a milestone or note")
        expect(response.body).not_to include("data-recap-prompt")
      end

      it "drops the stat tiles that had no action attached" do
        get "/dashboard"

        expect(response.body).not_to include("Total entries")
        expect(response.body).not_to include("Manual posts")
      end
    end
  end

  # Three places a builder goes, plus an account menu. It used to be up to
  # eight links in a row, which wrapped on a phone.
  describe "signed-in nav" do
    let(:user) { create(:user, username: "builder") }

    before { sign_in_as(user) }

    it "has Dashboard, Recap and My page, and tucks the rest into a menu" do
      get "/dashboard"

      nav = response.body[/<header.*?<\/header>/m]
      expect(nav).to include(">Dashboard<", ">Recap<", ">My page<")
      expect(nav).to include('aria-current="page"')

      menu = nav[/<details.*?<\/details>/m]
      expect(menu).to include(">Settings<", ">Explore builders<", "Sign out")
      expect(menu).not_to include(">Admin<")
    end
  end
end
