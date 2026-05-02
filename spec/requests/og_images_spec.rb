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
