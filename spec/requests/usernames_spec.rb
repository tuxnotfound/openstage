require "rails_helper"

RSpec.describe "Usernames", type: :request do
  describe "GET /claim-username" do
    context "with no pending user in session" do
      it "redirects to root" do
        get "/claim-username"
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
