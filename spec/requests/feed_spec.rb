require "rails_helper"

RSpec.describe "Feed", type: :request do
  describe "GET /feed" do
    it "is public, so it is a real discovery surface for crawlers and visitors" do
      builder = create(:user, username: "builder")
      create(:entry, user: builder, title: "shipped something public")

      get "/feed"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("shipped something public")
    end

    it "is linked from every public profile" do
      create(:user, username: "someone")

      get "/someone"
      expect(response.body).to include('href="/feed"')
      expect(response.body).to include("Explore other builders")
    end
  end

  describe "the free-tier footer" do
    it "sits after the timeline, not above the profile header" do
      create(:user, username: "freebie")

      get "/freebie"
      expect(response.body.index("data-claim-cta")).to be > response.body.index("Profile header")
    end

    it "carries a ref tag so footer-driven signups are attributable" do
      create(:user, username: "freebie2")

      get "/freebie2"
      expect(response.body).to include("?ref=footer")
    end

    it "stays hidden for Pro profiles" do
      create(:user, username: "paid", pro: true)

      get "/paid"
      expect(response.body).not_to include("data-claim-cta")
      expect(response.body).to include("Explore other builders")
    end
  end
end
