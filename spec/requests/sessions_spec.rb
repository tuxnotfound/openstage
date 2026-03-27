require "rails_helper"

RSpec.describe "Sessions", type: :request do
  describe "GET /auth/github/callback" do
    context "when user already exists" do
      let!(:user) { create(:user) }

      it "signs the user in and redirects to dashboard" do
        sign_in_as(user)
        expect(response).to redirect_to(dashboard_path)
      end
    end

    context "when user is new" do
      it "stores pending user in session and redirects to username claim" do
        OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
          uid: "brand_new_uid_99999",
          info: { nickname: "newgithubuser", name: "New User", image: "https://avatars.example.com/u/99" },
          credentials: { token: "gho_new_token" }
        )
        allow(GithubSyncJob).to receive(:perform_later)
        get "/auth/github/callback"
        expect(response).to redirect_to(new_username_path)
      end
    end
  end

  describe "DELETE /sign_out" do
    let!(:user) { create(:user) }

    it "signs the user out and redirects to root" do
      sign_in_as(user)
      delete sign_out_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /auth/failure" do
    it "redirects to root with an alert" do
      get "/auth/failure", params: { message: "access_denied" }
      expect(response).to redirect_to(root_path)
    end
  end
end
