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

      it "renders period-over-period deltas when there is prior data" do
        create_list(:profile_view, 6, user: user, viewed_at: 2.days.ago)
        create_list(:profile_view, 2, user: user, viewed_at: 10.days.ago)

        get "/analytics", params: { range: "7" }

        expect(response).to have_http_status(:success)
        # 6 vs 2 = +200%; rendered with arrow + percent.
        expect(response.body).to match(/↑\s*200%/)
      end

      it "classifies referrers into named buckets in the Traffic sources section" do
        create(:profile_view, user: user, viewed_at: 1.day.ago, referrer: "news.ycombinator.com")
        create(:profile_view, user: user, viewed_at: 1.day.ago, referrer: "x.com")

        get "/analytics", params: { range: "7" }

        expect(response.body).to include("Traffic sources")
        expect(response.body).to include("Hacker News")
        expect(response.body).to include("Twitter / X")
      end

      it "renders badge and embed impression cards" do
        create_list(:badge_impression, 4, user: user, kind: "badge", viewed_at: 1.day.ago)
        create_list(:badge_impression, 2, user: user, kind: "embed", viewed_at: 1.day.ago)

        get "/analytics", params: { range: "7" }

        expect(response.body).to include("README badge")
        expect(response.body).to include("Embed widget")
      end

      it "shows a click rate when the entry has enough profile views since publish" do
        entry = create(:entry, user: user, title: "Big launch", created_at: 8.days.ago, occurred_at: 8.days.ago)
        create_list(:profile_view, 20, user: user, viewed_at: 6.days.ago)
        create_list(:entry_click, 4, user: user, entry: entry, clicked_at: 5.days.ago)

        get "/analytics", params: { range: "30" }

        expect(response.body).to include("Big launch")
        expect(response.body).to include("click rate")
      end
    end
  end
end
