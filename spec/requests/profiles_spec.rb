require "rails_helper"

RSpec.describe "Profiles", type: :request do
  describe "GET /:username" do
    context "when user exists" do
      let!(:user) { create(:user, username: "testuser") }

      it "returns http success" do
        get "/testuser"
        expect(response).to have_http_status(:success)
      end
    end

    context "when user does not exist" do
      it "returns 404" do
        get "/nobody_here_xyz"
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
