require "rails_helper"

RSpec.describe "Badges", type: :request do
  describe "GET /badge/:username" do
    let!(:user) { create(:user, username: "builder") }

    it "returns an SVG badge for active users without requiring the extension" do
      create(:entry, user: user, entry_type: "shipped", source: "github", occurred_at: 2.days.ago)
      create(:entry, user: user, entry_type: "note", source: "manual", occurred_at: 1.day.ago)

      get "/badge/builder"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("image/svg+xml")
      expect(response.body).to include("openstage")
      expect(response.body).to include("1 commits | 2 entries")
    end

    it "still supports the .svg path" do
      get "/badge/builder.svg"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("image/svg+xml")
    end

    it "returns 404 for missing users" do
      get "/badge/ghost"
      expect(response).to have_http_status(:not_found)
    end

    it "records a badge impression on each request" do
      expect {
        get "/badge/builder"
      }.to change { user.badge_impressions.where(kind: "badge").count }.by(1)
    end
  end
end
