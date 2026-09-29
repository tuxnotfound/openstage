require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "returns http success" do
      get "/"
      expect(response).to have_http_status(:success)
    end

    it "leads with the friction, not a feature list" do
      get "/"

      expect(response.body).to include("Keep shipping.")
      expect(response.body).to include("Openstage does the showing.")
      expect(response.body).to include("Start free with GitHub")
    end

    # The feed sold a network of a handful of people, which is the framing the
    # rebirth dropped. The landing shows one real page, never other builders.
    it "does not show a feed of other builders' entries" do
      stranger = create(:user, username: "alice")
      create(:entry, user: stranger, entry_type: "shipped", source: "github", title: "Shipped v1", occurred_at: 1.hour.ago)

      get "/"

      expect(response.body).not_to include("Live public feed")
      expect(response.body).not_to include("Shipped v1")
      expect(response.body).not_to include("@alice")
    end

    it "shows only public entries of the demo page" do
      demo = create(:user, username: "tuxnotfound")
      create(:entry, user: demo, title: "Public entry", entry_type: "note", source: "manual", occurred_at: 1.hour.ago)
      create(:entry, user: demo, title: "Hidden entry", hidden: true, entry_type: "note", source: "manual", occurred_at: 2.hours.ago)
      create(:entry, user: demo, title: "Private entry", visibility: "private", entry_type: "note", source: "manual", occurred_at: 3.hours.ago)

      get "/"

      expect(response.body).to include("Public entry")
      expect(response.body).not_to include("Hidden entry")
      expect(response.body).not_to include("Private entry")
    end
  end
end
