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
    it "says what connecting Stripe reads, what it keeps and how it goes" do
      get "/privacy"

      section = Nokogiri::HTML(response.body).at_css("#stripe").text.squish
      expect(section).to include("read the account's products, prices, subscriptions and invoices")
      expect(section).to include("It keeps those daily totals, and each product's name, Stripe id and whether it is archived.")
      expect(section).to include("no invoice, no subscription and no customer's record is kept")
      expect(section).to include("Disconnecting Stripe in Settings deletes the key and everything read with it at once.")
    end

    it "says what the script counts on builders' sites, linked from every page's footer" do
      get "/privacy"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("On a builder's website", "deletes it within three days")
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
        "It counts each page by its path, without the query string, and replaces with an asterisk any part of the path that looks " \
        "like an email address, and most that look like a long id or token.",
        "Once a day, it also counts the name of the site you came from, the ref or utm_source tag in the " \
        "page's address, and your country as Cloudflare reports it.",
        "deletes it within three days. For an IPv6 address, it hashes only the first half, the part that names your network. " \
        "It does not keep your IP address or your device."
      )
    end

    it "says a builder's time zone is saved, and where it changes" do
      get "/privacy"

      expect(Nokogiri::HTML(response.body).text.squish).to include("Openstage also saves your browser's time zone to count your days in it, and you can change it in Settings.")
    end

    it "says what a visit and a click on Openstage's own pages keep, and that its request log leaves out the address" do
      get "/privacy"

      page = Nokogiri::HTML(response.body)
      own_pages = page.at_css("section[aria-labelledby='on-openstage']").text.squish
      expect(own_pages).to include(
        "and a hash of your IP address with the date, not the address itself. The hash is made with a secret key, so " \
        "without that key it cannot be turned back into the address.",
        "Openstage deletes it within three days and keeps a random ID in its place, which says only which of that day's " \
        "visits came from the same visitor.",
        "A click on a page's links records the link and the time.",
        "Openstage's request log leaves out your IP address, on its own pages and for the script's page views."
      )
      expect(own_pages).not_to include("the same hash")
      expect(page.text.squish).to include("Updated November 9, 2026.")
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

    it "says MRR shows on project pages on Pro, and only to its builder on Free" do
      get "/pricing"

      page = Nokogiri::HTML(response.body).text.squish
      expect(page).to include("One project's MRR from Stripe, seen only by you")
      expect(page).to include("MRR and paying customers on every project's page.", "Verified with Stripe. Hide either one whenever you like.")
      expect(page).to include("How does Openstage count MRR?", "A refund does not change it.")
    end

    it "shows the upgrade CTA for signed-out visitors" do
      get "/pricing"

      expect(response.body).to include("Sign in to go Pro")
    end
  end
end
