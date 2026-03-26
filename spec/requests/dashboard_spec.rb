require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  describe "GET /dashboard" do
    context "when not signed in" do
      it "redirects to root" do
        get "/dashboard"
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
