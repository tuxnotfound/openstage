require "rails_helper"

RSpec.describe ReferrerClassifier do
  describe ".label" do
    it "returns Direct for blank input" do
      expect(described_class.label(nil)).to eq("Direct")
      expect(described_class.label("")).to eq("Direct")
    end

    it "names known referrers regardless of www, Openstage too" do
      expect(described_class.label("news.ycombinator.com")).to eq("Hacker News")
      expect(described_class.label("www.reddit.com")).to eq("Reddit")
      expect(described_class.label("old.reddit.com")).to eq("Reddit")
      expect(described_class.label("twitter.com")).to eq("Twitter / X")
      expect(described_class.label("x.com")).to eq("Twitter / X")
      expect(described_class.label("t.co")).to eq("Twitter / X")
      expect(described_class.label("producthunt.com")).to eq("Product Hunt")
      expect(described_class.label("github.com")).to eq("GitHub")
      expect(described_class.label("linkedin.com")).to eq("LinkedIn")
      expect(described_class.label("www.openstage.dev")).to eq("Openstage")
    end

    it "groups Google subdomains" do
      expect(described_class.label("google.com")).to eq("Google")
      expect(described_class.label("www.google.co.uk")).to eq("Google")
      expect(described_class.label("news.google.com")).to eq("Google")
    end

    it "gives any other host as itself, lowercased, www. dropped, never Other" do
      expect(described_class.label("somerandomblog.dev")).to eq("somerandomblog.dev")
      expect(described_class.label("WWW.IndieHackers.com")).to eq("indiehackers.com")
    end
  end

  describe ".known" do
    it "names the sites the rules know, and no other host" do
      expect([ described_class.known("www.news.ycombinator.com"), described_class.known("t.co"), described_class.known("google.de") ]).to eq([ "Hacker News", "Twitter / X", "Google" ])
      expect([ described_class.known("somerandomblog.dev"), described_class.known(nil) ]).to eq([ nil, nil ])
    end

    it "names Gmail apart from Google, and an Android app as its site" do
      expect(%w[mail.google.com com.google.android.gm].map { |host| described_class.known(host) }).to eq(%w[Gmail Gmail])
      expect(%w[com.google.android.googlequicksearchbox news.google.com].map { |host| described_class.known(host) }).to eq(%w[Google Google])
      expect(%w[com.twitter.android com.reddit.frontpage com.linkedin.android].map { |host| described_class.known(host) }).to eq([ "Twitter / X", "Reddit", "LinkedIn" ])
    end
  end
end
