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

    it "counts only the demo page's public commits" do
      demo = create(:user, username: "tuxnotfound")
      create(:entry, user: demo)
      create(:entry, user: demo, hidden: true)
      create(:entry, user: demo, visibility: "private")

      get "/"

      expect(response.body).to match(%r{<span class="os-num[^"]*">1</span>\s*<span[^>]*>commits, last 12 months})
    end
  end
end
