require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "returns http success" do
      get "/"
      expect(response).to have_http_status(:success)
    end

    it "shows recent public activity entries" do
      user = create(:user, username: "alice")
      entry = create(:entry, user: user, entry_type: "shipped", source: "github", title: "Shipped v1", occurred_at: 1.hour.ago)

      get "/"

      expect(response.body).to include("Live builder activity")
      expect(response.body).to include(entry.title)
      expect(response.body).to include("@alice")
    end

    it "does not show hidden, private, or deleted-user entries" do
      visible_user = create(:user, username: "visible")
      deleted_user = create(:user, username: "gone", deleted_at: Time.current)

      create(:entry, user: visible_user, title: "Public entry", entry_type: "note", source: "manual", occurred_at: 1.hour.ago)
      create(:entry, user: visible_user, title: "Hidden entry", hidden: true, entry_type: "note", source: "manual", occurred_at: 2.hours.ago)
      create(:entry, user: visible_user, title: "Private entry", visibility: "private", entry_type: "note", source: "manual", occurred_at: 3.hours.ago)
      create(:entry, user: deleted_user, title: "Deleted user entry", entry_type: "note", source: "manual", occurred_at: 4.hours.ago)

      get "/"

      expect(response.body).to include("Public entry")
      expect(response.body).not_to include("Hidden entry")
      expect(response.body).not_to include("Private entry")
      expect(response.body).not_to include("Deleted user entry")
    end
  end
end
