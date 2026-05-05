require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  describe "GET /dashboard" do
    context "when not signed in" do
      it "redirects to root" do
        get "/dashboard"
        expect(response).to redirect_to(root_path)
      end
    end

    context "when signed in" do
      let(:user) { create(:user, username: "builder") }

      before { sign_in_as(user) }

      it "does not show README badge snippet" do
        get "/dashboard"

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include("README badge")
        expect(response.body).not_to include("/badge/builder")
      end
    end
  end
end
