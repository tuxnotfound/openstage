require "rails_helper"

RSpec.describe "Embeds", type: :request do
  describe "GET /embed/:username/preview" do
    let!(:user) { create(:user, username: "builder", display_name: "Builder") }

    it "renders an embed preview page" do
      get "/embed/builder/preview"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Embed preview for @builder")
      expect(response.body).to include("/embed/builder.js")
    end

    it "returns 404 for missing users" do
      get "/embed/ghost/preview"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /embed/:username.js" do
    let!(:user) { create(:user, username: "builder", display_name: "Builder") }

    it "returns JavaScript for an active user" do
      create(:entry, user: user, entry_type: "shipped", source: "github", title: "Shipped v1", occurred_at: 1.hour.ago)

      get "/embed/builder.js"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/javascript")
      expect(response.body).to include("What I'm building")
      expect(response.body).to include("Shipped v1")
      expect(response.body).to include("/builder")
    end

    it "returns 404 for missing users" do
      get "/embed/ghost.js"
      expect(response).to have_http_status(:not_found)
    end

    it "records an embed impression on each request" do
      expect {
        get "/embed/builder.js"
      }.to change { user.badge_impressions.where(kind: "embed").count }.by(1)
    end
  end
end
