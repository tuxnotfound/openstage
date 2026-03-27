require "rails_helper"

RSpec.describe "Settings", type: :request do
  let!(:user) { create(:user) }

  describe "GET /settings" do
    context "when not signed in" do
      it "redirects to root" do
        get settings_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "when signed in" do
      it "returns http success" do
        sign_in_as(user)
        get settings_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "PATCH /settings" do
    context "when signed in" do
      before { sign_in_as(user) }

      it "updates profile and redirects with notice" do
        patch settings_path, params: { user: { display_name: "New Name", bio: "Hello" } }
        expect(response).to redirect_to(settings_path)
        expect(user.reload.display_name).to eq("New Name")
      end
    end
  end

  describe "PATCH /settings/username" do
    context "when signed in and username change is allowed" do
      before { sign_in_as(user) }

      it "updates username and redirects" do
        patch settings_username_path, params: { user: { username: "newusername" } }
        expect(response).to redirect_to(settings_path)
        expect(user.reload.username).to eq("newusername")
      end
    end

    context "when username was changed less than 30 days ago" do
      before do
        user.update!(username_changed_at: 10.days.ago)
        sign_in_as(user)
      end

      it "redirects with alert and does not change username" do
        original_username = user.username
        patch settings_username_path, params: { user: { username: "anotherhandle" } }
        expect(response).to redirect_to(settings_path)
        expect(user.reload.username).to eq(original_username)
      end
    end
  end

  describe "DELETE /settings" do
    context "when signed in" do
      before { sign_in_as(user) }

      it "soft deletes the account and redirects to root" do
        delete settings_path
        expect(response).to redirect_to(root_path)
        expect(user.reload.deleted_at).not_to be_nil
      end
    end
  end
end
