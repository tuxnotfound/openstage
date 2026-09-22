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

      it "creates a user and lands them on their own page, which says it is syncing" do
        expect { post claim_username_path, params: { username: "mynewhandle" } }.to change(User, :count).by(1)
        expect(response).to redirect_to("/mynewhandle")

        follow_redirect!
        expect(response.body).to include("data-syncing")
        expect(response.body).to include('http-equiv="refresh"')
      end

      it "stops saying syncing once the first sync has logged, and shows the honest thin state" do
        post claim_username_path, params: { username: "mynewhandle" }
        User.find_by(username: "mynewhandle").sync_logs.create!(source: "github", status: "success", ran_at: Time.current)

        get "/mynewhandle"
        expect(response.body).not_to include("data-syncing")
        expect(response.body).to include("Nothing public in the last 90 days")
        expect(response.body).to include("Log a milestone")
      end

      it "never shows the syncing state to a visitor" do
        post claim_username_path, params: { username: "mynewhandle" }
        reset!

        get "/mynewhandle"
        expect(response.body).not_to include("data-syncing")
        expect(response.body).to include("no public activity")
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
