require "rails_helper"

RSpec.describe "Badges", type: :request do
  describe "GET /badge/:username.svg" do
    let!(:user) { create(:user, username: "builder") }

    it "returns an SVG badge for active users" do
      create(:entry, user: user, entry_type: "shipped", source: "github", occurred_at: 2.days.ago)
      create(:entry, user: user, entry_type: "note", source: "manual", occurred_at: 1.day.ago)

      get "/badge/builder.svg"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("image/svg+xml")
      expect(response.body).to include("openstage")
      expect(response.body).to include("1 commits | 2 entries")
    end

    it "returns 404 for missing users" do
      get "/badge/ghost.svg"
      expect(response).to have_http_status(:not_found)
    end
  end
end
