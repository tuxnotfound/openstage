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
      expect(response.body).to include("On a builder's website", "deletes it within two days")
      expect(Nokogiri::HTML(response.body).text.squish).to include(
        "Openstage does not count views from bots, from sites other than the project's own, or on a project's site while its counting is off or paused."
      )
      expect(Nokogiri::HTML(response.body).at_css("#builders-sites").text.squish).to include(
        "The builder sees these totals, and the builder's stage and the project's page on Openstage can show the project's page views and visitors."
      )
      expect(response.body).to include(%(href="/privacy"))
    end

    it "says what the script keeps of each view, and what it never keeps" do
      get "/privacy"

      expect(Nokogiri::HTML(response.body).at_css("#builders-sites").text.squish).to include(
        "When a page loads, it also sends the address of the page you came from.",
        "page views, and visitors, a visitor being one IP address, or one IPv6 network, on one day.",
        "It sets no cookie and stores nothing in your browser.",
        "It counts each page by its path, without the query string, and replaces any part of the path that looks like an email " \
        "address or a code with an asterisk.",
        "Once a day, it also counts the name of the site you came from, the ref or utm_source tag in the " \
        "page's address, and your country as Cloudflare reports it.",
        "deletes it within two days. For an IPv6 address, it hashes only the first half, the part that names your network. " \
        "It does not keep your IP address or your device."
      )
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
