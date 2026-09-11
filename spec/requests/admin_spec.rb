require "rails_helper"

RSpec.describe "Admin", type: :request do
  let(:owner) { create(:user, github_username: "tuxnotfound", username: "tuxnotfound") }

  describe "GET /admin" do
    it "404s when signed out" do
      get "/admin"
      expect(response).to have_http_status(:not_found)
    end

    it "404s for another signed-in user" do
      sign_in_as(create(:user, github_username: "someone_else"))
      get "/admin"
      expect(response).to have_http_status(:not_found)
    end

    context "as the owner" do
      before { sign_in_as(owner) }

      it "renders without dividing by zero when nobody has activated" do
        get "/admin"
        expect(response).to have_http_status(:success)
        expect(response.body).to include("0% of signups")
      end

      it "groups signups by first touch" do
        create(:user, username: "fromrecap", signup_ref: "recap", created_at: 2.days.ago)
        active = create(:user, username: "active", signup_ref: "recap", created_at: 3.days.ago)
        create(:entry, user: active)
        create(:user, username: "direct_one", signup_ref: "direct", created_at: 4.days.ago)

        get "/admin"
        expect(response.body).to include('data-ref="recap" data-count="2"')
        expect(response.body).to include('data-ref="direct" data-count="1"')
      end

      it "ignores signups outside the window" do
        create(:user, username: "ancient", signup_ref: "recap", created_at: 90.days.ago)

        get "/admin"
        expect(response.body).not_to include('data-ref="recap"')
      end

      it "labels rows that predate ref tagging rather than dropping them" do
        create(:user, username: "old_row", signup_ref: nil, created_at: 2.days.ago)

        get "/admin"
        expect(response.body).to include('data-ref="unattributed"')
      end

      it "is reachable from the nav" do
        get "/dashboard"
        expect(response.body).to include('href="/admin"')
      end
    end
  end
end
