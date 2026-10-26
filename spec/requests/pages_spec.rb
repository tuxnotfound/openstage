require "rails_helper"

RSpec.describe "Marketing pages", type: :request do
  describe "GET /about" do
    it "renders the about page with title and canonical" do
      get "/about"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("About Openstage")
      expect(response.body).to include('<link rel="canonical"')
    end
  end

  describe "GET /privacy" do
    it "says what the script counts on builders' sites, linked from every page's footer" do
      get "/privacy"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("On a builder's website", "deletes it once the day is over")
      expect(response.body).to include(%(href="/privacy"))
    end
  end

  describe "GET /pricing" do
    it "renders the pricing page with the real prices" do
      get "/pricing"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Pro is $7 a month")
      expect(response.body).not_to include("$49")
      expect(response.body).to include("application/ld+json")
    end

    it "shows the upgrade CTA for signed-out visitors" do
      get "/pricing"

      expect(response.body).to include("Sign in to go Pro")
    end
  end
end
