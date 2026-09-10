require "rails_helper"

RSpec.describe "Diagnostics", type: :request do
  describe "GET /_deploy_check" do
    context "when not signed in" do
      it "returns 404" do
        get "/_deploy_check"
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed in as a non-owner" do
      let(:user) { create(:user, github_username: "someone_else") }
      before { sign_in_as(user) }

      it "returns 404" do
        get "/_deploy_check"
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed in as the owner" do
      let(:user) { create(:user, github_username: "tuxnotfound") }
      before { sign_in_as(user) }

      it "reports the deployed commit and migration state" do
        get "/_deploy_check"
        expect(response).to have_http_status(:success)
        expect(response.body).to include("env:")
        expect(response.body).to include("commit:")
        expect(response.body).to include("pending:")
        expect(response.body).to include("users.email:     true")
      end
    end
  end
end
