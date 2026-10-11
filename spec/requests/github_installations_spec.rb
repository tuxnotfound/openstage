require "rails_helper"
require "support/github_app"

RSpec.describe "GitHub App installations", type: :request do
  let(:user) { create(:user, github_uid: "123", github_username: "tuxnotfound") }
  let(:not_found) { ApplicationGateway::NotFound.new(status: 404) }
  let(:integrations) { settings_path(tab: "integrations") }

  def installed!
    allow(GithubAppGateway).to receive(:user_installation).with("tuxnotfound").and_return(id: 7, account_id: 123)
    allow(GithubAppGateway).to receive(:installation_repositories).with(7).and_return([])
  end

  def not_installed!
    allow(GithubAppGateway).to receive(:user_installation).and_raise(not_found)
  end

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
        not_installed!
        sign_in_as(user)
        get new_github_installation_path
        expect(response).to redirect_to("https://github.com/apps/openstage-test/installations/new")
      end

      # GitHub's page for an existing installation never sends the builder back.
      it "connects an App that is already installed without leaving Openstage" do
        installed!
        sign_in_as(user)
        get new_github_installation_path

        expect(response).to redirect_to(integrations)
        expect(flash[:notice]).to include("Private repos connected, read-only")
        expect(user.reload.github_installation_id).to eq(7)
      end
    end
  end

  describe "GET /github_app/callback" do
    include_context "with the GitHub App configured"

    it "requires sign-in" do
      get github_installation_callback_path, params: { installation_id: "7", setup_action: "install" }
      expect(response).to redirect_to(root_path)
    end

    it "connects the installation GitHub reports for the builder, not the one in the URL" do
      installed!
      sign_in_as(user)
      get github_installation_callback_path, params: { installation_id: "99", setup_action: "install" }

      expect(response).to redirect_to(integrations)
      expect(flash[:notice]).to include("Private repos connected, read-only")
      expect(user.reload.github_installation_id).to eq(7)
    end

    it "explains when the App is not on the builder's account" do
      not_installed!
      sign_in_as(user)
      get github_installation_callback_path, params: { setup_action: "request" }

      expect(response).to redirect_to(integrations)
      expect(flash[:alert]).to include("not installed on your GitHub account")
    end

    it "answers with an alert when GitHub is down" do
      allow(GithubAppGateway).to receive(:user_installation).and_raise(ApplicationGateway::ServerError.new(status: 502))
      sign_in_as(user)
      get github_installation_callback_path

      expect(response).to redirect_to(integrations)
      expect(flash[:alert]).to include("GitHub did not answer")
    end
  end
end
