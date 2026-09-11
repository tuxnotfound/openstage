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

      it "reports a clean bill when every stored URL is http(s)" do
        create(:user, username: "fine", website_url: "https://example.com")

        get "/_deploy_check"
        expect(response.body).to include("unsafe_websites: none")
        expect(response.body).to include("unsafe_entries:  0")
      end

      it "names any pre-validation row still holding an unsafe scheme" do
        bad = create(:user, username: "legacy", website_url: "https://example.com")
        bad.update_column(:website_url, "javascript:alert(1)")
        entry = create(:entry, user: bad, url: "https://example.com")
        entry.update_column(:url, "javascript:alert(1)")

        get "/_deploy_check"
        expect(response.body).to include("unsafe_websites: 1 (legacy=javascript:alert(1))")
        expect(response.body).to include("unsafe_entries:  1")
      end
    end
  end
end
