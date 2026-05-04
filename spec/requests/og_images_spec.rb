require "rails_helper"

RSpec.describe "OgImages", type: :request do
  describe "GET /og/:username" do
    let(:user) { create(:user) }

    it "returns a PNG for an active user" do
      allow(OgImageGenerator).to receive(:call).and_return("PNGDATA")

      get "/og/#{user.username}"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("image/png")
      expect(response.body).to eq("PNGDATA")
      expect(OgImageGenerator).to have_received(:call).with(
        user,
        entries_count: 0,
        repos_count: 0,
        milestones_count: 0,
        recent_commits_count: 0,
        streak_count: 0
      )
    end

    it "passes profile metrics to the generator" do
      create(:github_repo, user: user)
      create(:entry, user: user, entry_type: "shipped", source: "github", occurred_at: 2.days.ago)
      create(:entry, user: user, entry_type: "milestone", source: "manual", occurred_at: 1.day.ago)

      allow(OgImageGenerator).to receive(:call).and_return("PNGDATA")

      get "/og/#{user.username}"

      expect(OgImageGenerator).to have_received(:call).with(
        user,
        entries_count: 2,
        repos_count: 1,
        milestones_count: 1,
        recent_commits_count: 1,
        streak_count: 2
      )
    end

    it "returns fallback PNG when generation fails" do
      allow(OgImageGenerator).to receive(:call).and_raise(ArgumentError, "wrong number of arguments")

      get "/og/#{user.username}"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("image/png")
      expect(response.body.b).to eq(OgImagesController::FALLBACK_PNG)
    end

    it "returns not found for unknown usernames" do
      get "/og/does-not-exist"

      expect(response).to have_http_status(:not_found)
    end
  end
end
