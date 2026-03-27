require "rails_helper"

RSpec.describe "Usernames", type: :request do
  describe "GET /claim-username" do
    context "with no pending user in session" do
      it "redirects to root" do
        get new_username_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "with a pending user in session" do
      before do
        OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
          uid: "pending_uid_12345",
          info: { nickname: "pendinguser", name: "Pending User", image: "https://avatars.example.com/u/5" },
          credentials: { token: "gho_pending_token" }
        )
        allow(GithubSyncJob).to receive(:perform_later)
        get "/auth/github/callback"
      end

      it "returns http success" do
        get new_username_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /claim-username" do
    context "with a pending user in session and a valid username" do
      before do
        OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
          uid: "claim_uid_99",
          info: { nickname: "claimuser", name: "Claim User", image: "https://avatars.example.com/u/6" },
          credentials: { token: "gho_claim_token" }
        )
        allow(GithubSyncJob).to receive(:perform_later)
        get "/auth/github/callback"
      end

      it "creates a user and redirects to dashboard" do
        expect { post claim_username_path, params: { username: "mynewhandle" } }.to change(User, :count).by(1)
        expect(response).to redirect_to(dashboard_path)
      end
    end

    context "with a pending user in session and an invalid username" do
      before do
        OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
          uid: "claim_uid_invalid_88",
          info: { nickname: "invaliduser", name: "Invalid User", image: "https://avatars.example.com/u/7" },
          credentials: { token: "gho_invalid_token" }
        )
        allow(GithubSyncJob).to receive(:perform_later)
        get "/auth/github/callback"
      end

      it "does not create a user and re-renders the form" do
        expect { post claim_username_path, params: { username: "a" } }.not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
