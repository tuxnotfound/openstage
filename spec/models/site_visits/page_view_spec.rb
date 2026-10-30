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

    it "masks a part that holds an email, a UUID or a long token mixing letters and digits" do
      expect(view(url: "https://shipnote.app/u/jane@example.com/settings").page).to eq("/u/*/settings")
      expect(view(url: "https://shipnote.app/invite/jane%40example.com").page).to eq("/invite/*")
      expect(view(url: "https://shipnote.app/orders/123E4567-e89b-12d3-a456-426614174000/").page).to eq("/orders/*")
      expect(view(url: "https://shipnote.app/reset/Zx9_Kq2-Lm8pRt4vWy6bNc3d").page).to eq("/reset/*")
    end

    it "keeps a long part of letters alone, or of digits alone, and a short token" do
      expect(view(url: "https://shipnote.app/blog/how-we-priced-shipnote-for-teams").page).to eq("/blog/how-we-priced-shipnote-for-teams")
      expect(view(url: "https://shipnote.app/orders/123456789012345678901234").page).to eq("/orders/123456789012345678901234")
      expect(view(url: "https://shipnote.app/p/Zx9Kq2Lm8pRt4vWy6bNc3d").page).to eq("/p/Zx9Kq2Lm8pRt4vWy6bNc3d")
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
  end
end
