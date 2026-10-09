require "rails_helper"
require "support/github_app"

RSpec.describe "GitHub App installations", type: :request do
  let(:user) { create(:user, github_uid: "123", github_username: "tuxnotfound") }

  describe "GET /github_app/install" do
    it "requires sign-in" do
      get new_github_installation_path
      expect(response).to redirect_to(root_path)
    end

    it "is not found while the App is not registered" do
      sign_in_as(user)
      get new_github_installation_path
      expect(response).to have_http_status(:not_found)
    end

    context "with the App registered" do
      include_context "with the GitHub App configured"

      it "sends the builder to GitHub to pick repos" do
        sign_in_as(user)
        get new_github_installation_path
        expect(response).to redirect_to("https://github.com/apps/openstage-test/installations/new")
      end
    end
  end

  describe "GET /github_app/callback" do
    let(:params) { { code: "abc", installation_id: "7", setup_action: "install" } }

    before do
      allow(GithubOauthGateway).to receive(:user_token).with("abc").and_return("ghu_user")
      allow(GithubAppGateway).to receive(:installations).with("ghu_user")
        .and_return([ { id: 7, account_id: 123, account_login: "tuxnotfound" } ])
    end

    it "requires sign-in" do
      get github_installation_callback_path, params: params
      expect(response).to redirect_to(root_path)
    end

    it "connects the installation and returns to Settings" do
      sign_in_as(user)
      get github_installation_callback_path, params: params

      expect(response).to redirect_to(settings_path)
      expect(flash[:notice]).to include("Private repos connected, read-only")
      expect(user.reload.github_installation_id).to eq(7)
      expect(GithubSyncJob).to have_received(:perform_later).with(user.id).at_least(:once)
    end

    it "explains a refused installation" do
      sign_in_as(user)
      get github_installation_callback_path, params: params.merge(installation_id: "99")

      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to include("did not list that installation")
      expect(user.reload.github_installation_id).to be_nil
    end

    it "answers with an alert when GitHub is down" do
      allow(GithubOauthGateway).to receive(:user_token).and_raise(ApplicationGateway::ServerError.new(status: 502))
      sign_in_as(user)
      get github_installation_callback_path, params: params

      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to include("GitHub did not answer")
    end
  end
end
