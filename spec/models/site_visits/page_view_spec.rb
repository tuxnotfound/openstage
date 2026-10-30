require "rails_helper"

RSpec.describe SiteVisits::PageView do
  def view(url: "https://shipnote.app/", referrer: "", country: nil)
    described_class.new(url: url, referrer: referrer, country: country, site_host: "shipnote.app")
  end

  describe "#page" do
    it "keeps the path alone, without its query, fragment or trailing slash, except on /" do
      expect(view(url: "https://shipnote.app/pricing/?plan=pro&email=jane@example.com#faq").page).to eq("/pricing")
      expect([ view(url: "https://shipnote.app").page, view(url: "https://shipnote.app/").page, view(url: "https://shipnote.app/?ref=hn").page ]).to eq(%w[/ / /])
      expect(view(url: "https://shipnote.app/Blog/Launch-Day").page).to eq("/Blog/Launch-Day")
    end

    it "masks a part that holds an email address, a UUID, a digest, an id, a token or a phone number" do
      masked = [
        "jane@example.com", "jane%40example.com", "550e8400-e29b-41d4-a716-446655440000", "550E8400-E29B-41D4-A716-446655440000",
        "invoice-550e8400-e29b-41d4-a716-446655440000", "9e107d9d372bb6826bd81d3542a419d6", "2fd4e1c67a2d28fced849ee1bb76e7391b93eb12",
        "d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592", "507f1f77bcf86cd799439011", "pX27zsMN2ViQKta1bGfLmVJE",
        "V1StGXR8_Z5jdHi6B-myT", "zyx-9QcN2_Pe7mBv1Hk3", "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U",
        "4155551234"
      ]

      expect(masked.to_h { |part| [ part, view(url: "https://shipnote.app/u/#{part}/settings").page ] }).to eq(masked.to_h { |part| [ part, "/u/*/settings" ] })
    end

    it "keeps a slug, in title case or with a product's name too, a handle, a number and a version" do
      kept = %w[launching-v2-of-shipnote-today 2026-10-30-release-notes top-10-tips-for-rails-7-developers My-Trip-To-Paris-2026 @pedro 123 v2
                getting-started iPhone-15-Pro-Max-Review useEffect-in-React-18 GitHub-vs-GitLab-2026 B2B-SaaS-Metrics-101 how-we-priced-shipnote-for-teams]

      expect(kept.map { |part| view(url: "https://shipnote.app/blog/#{part}").page }).to eq(kept.map { |part| "/blog/#{part}" })
    end

    it "cuts a path at 200 characters" do
      expect(view(url: "https://shipnote.app/#{'docs/' * 60}end").page).to eq("/#{'docs/' * 60}end".first(200))
    end
  end

  describe "#source" do
    it "is the referrer's host, lowercased, www. dropped" do
      expect(view(referrer: "https://WWW.News.YCombinator.com/item?id=41&user=jane").source).to eq("news.ycombinator.com")
      expect(view(referrer: "android-app://com.google.android.gm/").source).to eq("com.google.android.gm")
    end

    it "is Direct for an empty referrer, and nothing without one" do
      expect([ view(referrer: "").source, view(referrer: nil).source ]).to eq([ SiteVisitCount::DIRECT, nil ])
    end

    it "is nothing from the project's own website, or from a referrer that names no host" do
      expect(view(referrer: "https://www.shipnote.app/pricing").source).to be_nil
      expect([ view(referrer: "hello").source, view(referrer: "not a url").source, view(referrer: "https://(direct)/").source ]).to eq([ nil, nil, nil ])
      expect(view(referrer: "https://#{'a' * 250}.example/").source).to be_nil
      expect([ view(referrer: "mailto:x").source, view(referrer: "mailto://news.example/").source, view(referrer: "ldap://a/%zz").source ]).to eq([ nil, nil, nil ])
    end
  end

  describe "#ref_tag" do
    it "takes ref first, then utm_source, the first one not blank" do
      expect(view(url: "https://shipnote.app/?utm_source=reddit&ref=HN").ref_tag).to eq("hn")
      expect(view(url: "https://shipnote.app/?ref=&utm_source=Reddit").ref_tag).to eq("reddit")
      expect(view(url: "https://shipnote.app/?ref=%F0%9F%9A%80&utm_source=newsletter").ref_tag).to eq("newsletter")
      expect(view(url: "https://shipnote.app/pricing").ref_tag).to be_nil
    end

    it "keeps letters, digits, dots, dashes and underscores, lowercased, at most 64" do
      expect(view(url: "https://shipnote.app/?ref=+Product%20Hunt!+").ref_tag).to eq("producthunt")
      expect(view(url: "https://shipnote.app/?utm_source=News.YCombinator.com").ref_tag).to eq("news.ycombinator.com")
      expect(view(url: "https://shipnote.app/?ref=launch_week-2").ref_tag).to eq("launch_week-2")
      expect(view(url: "https://shipnote.app/?ref=#{'a' * 80}").ref_tag).to eq("a" * 64)
    end
  end

  describe "#country" do
    it "is Cloudflare's two letters, and none for XX, T1 or blank" do
      expect([ view(country: "PT").country, view(country: "pt").country ]).to eq(%w[PT PT])
      expect([ view(country: "XX").country, view(country: "T1").country, view(country: "").country, view(country: nil).country ]).to eq([ nil ] * 4)
    end
  end

  describe "#counts" do
    let(:landing) { view(url: "https://shipnote.app/pricing?ref=hn", referrer: "https://news.ycombinator.com/", country: "PT") }

    it "adds the page, and on the visitor's first view of the day their source, ref tag and country" do
      expect(landing.counts(first: true)).to eq("page" => "/pricing", "source" => "news.ycombinator.com", "ref" => "hn", "country" => "PT")
      expect(landing.counts(first: false)).to eq("page" => "/pricing")
    end

    it "adds no source or ref tag to a first view sent without a referrer, and still its country" do
      sent_without = view(url: "https://shipnote.app/pricing?ref=hn", referrer: nil, country: "PT")

      expect(sent_without.counts(first: true)).to eq("page" => "/pricing", "country" => "PT")
    end

    it "adds the ref tag of a first view that came from the project's own website, and no source" do
      inside = view(url: "https://shipnote.app/pricing?ref=hn", referrer: "https://shipnote.app/", country: "XX")

      expect(inside.counts(first: true)).to eq("page" => "/pricing", "ref" => "hn")
    end
  end

  it "takes the bare domain and www. as one site, any case" do
    expect([ view.on_site?("https://WWW.shipnote.app/blog"), view.on_site?("https://shipnote.app.evil.example/"), view.on_site?(nil) ]).to eq([ true, false, false ])
    expect(view.on_site?("mailto://shipnote.app/")).to be(false)
  end
end
