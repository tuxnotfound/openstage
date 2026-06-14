require "rails_helper"

RSpec.describe "llms.txt", type: :request do
  describe "GET /llms.txt" do
    it "returns a plain-text summary for LLMs" do
      create(:user, username: "builder", bio: "Building cool things")

      get "/llms.txt"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/plain")
      expect(response.body).to include("# Openstage")
      expect(response.body).to include("$7/month or $49")
      expect(response.body).to include("/pricing")
      expect(response.body).to include("@builder")
    end
  end
end
