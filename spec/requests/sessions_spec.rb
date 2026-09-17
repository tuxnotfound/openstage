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

    # The Settings button posts scope=user:email,repo. omniauth-github forwards
    # a scope param into the authorize URL; pin that GitHub is actually asked,
    # since the request phase is what test mode short-circuits everywhere else.
    it "asks GitHub for the repo scope when Settings reconnects" do
      OmniAuth.config.test_mode = false
      post "/auth/github", params: { scope: "user:email,repo" }
      expect(response).to have_http_status(:redirect)
      expect(response.location).to start_with("https://github.com/login/oauth/authorize")
      expect(CGI.parse(URI(response.location).query)["scope"]).to eq([ "user:email,repo" ])
    ensure
      OmniAuth.config.test_mode = true
    end

    context "when the user reconnects with private-repo access" do
      let!(:user) { create(:user, github_access_token: "gho_narrow", github_token_scopes: "user:email") }

      it "adopts the token, syncs at once and lands on Settings" do
        OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
          uid: user.github_uid,
          info: { nickname: user.github_username, name: "Pedro", image: "https://avatars.example.com/u/1" },
          credentials: { token: "gho_repo_token" },
          extra: { scope: "repo,user:email" }
        )
        expect(GithubSyncJob).to receive(:perform_later).with(user.id)

        get "/auth/github/callback"

        expect(response).to redirect_to(settings_path)
        expect(user.reload).to have_attributes(github_access_token: "gho_repo_token", github_token_scopes: "repo,user:email")
      end
    end

    context "when user is new" do
      it "stores pending user in session and redirects to username claim" do
        OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
          uid: "brand_new_uid_99999",
          info: { nickname: "newgithubuser", name: "New User", image: "https://avatars.example.com/u/99" },
          credentials: { token: "gho_new_token" },
          extra: { scope: "user:email" }
        )
        allow(GithubSyncJob).to receive(:perform_later)
        get "/auth/github/callback"
        expect(response).to redirect_to(new_username_path)
        pending_user = session[:pending_user]
        expect(pending_user["github_token_scopes"] || pending_user[:github_token_scopes]).to eq("user:email")
      end

      it "prefills pending username from claimed profile" do
        OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
          uid: "brand_new_uid_claim_1000",
          info: { nickname: "newgithubuser", name: "New User", image: "https://avatars.example.com/u/100" },
          credentials: { token: "gho_claim_token" }
        )

        get "/nobody_here_xyz"
        get "/auth/github/callback"

        expect(response).to redirect_to(new_username_path)
        pending_user = session[:pending_user]
        proposed_username = pending_user["proposed_username"] || pending_user[:proposed_username]
        expect(proposed_username).to eq("nobody_here_xyz")
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
