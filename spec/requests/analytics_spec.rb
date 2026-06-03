require "rails_helper"

RSpec.describe "Analytics", type: :request do
  describe "GET /analytics" do
    context "when not signed in" do
      it "redirects to root" do
        get "/analytics"
        expect(response).to redirect_to(root_path)
      end
    end

    context "when signed in as a free user" do
      let(:user) { create(:user, pro: false) }
      before { sign_in_as(user) }

      it "redirects to the dashboard with a Pro-only message" do
        get "/analytics"
        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to match(/Pro/)
      end
    end

    context "when signed in as a Pro user" do
      let(:user) { create(:user, pro: true, username: "builder") }
      before { sign_in_as(user) }

      it "renders successfully with no data" do
        get "/analytics"
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Analytics")
      end

      it "renders with view, click, and entry data across ranges" do
        entry = create(:entry, user: user, title: "Launched v1")
        create_list(:profile_view, 3, user: user, viewed_at: 2.days.ago, country: "US")
        create(:profile_view, user: user, viewed_at: 2.days.ago, referrer: "https://news.ycombinator.com/")
        create_list(:entry_click, 5, user: user, entry: entry, clicked_at: 1.day.ago)

        get "/analytics", params: { range: "7" }

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Launched v1")
        expect(response.body).to include("US")
        expect(response.body).to include("news.ycombinator.com")
      end

      it "accepts the all-time range" do
        get "/analytics", params: { range: "all" }
        expect(response).to have_http_status(:success)
        expect(response.body).to include("All time")
      end

      it "falls back to the default range when given junk" do
        get "/analytics", params: { range: "junk" }
        expect(response).to have_http_status(:success)
        expect(response.body).to include("30 days")
      end
    end
  end
end
