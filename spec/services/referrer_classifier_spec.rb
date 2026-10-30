require "rails_helper"

RSpec.describe ReferrerClassifier do
  describe ".classify" do
    it "returns Direct for blank input" do
      expect(described_class.classify(nil)).to eq("Direct")
      expect(described_class.classify("")).to eq("Direct")
    end

    it "classifies known referrers regardless of www" do
      expect(described_class.classify("news.ycombinator.com")).to eq("Hacker News")
      expect(described_class.classify("www.reddit.com")).to eq("Reddit")
      expect(described_class.classify("old.reddit.com")).to eq("Reddit")
      expect(described_class.classify("twitter.com")).to eq("Twitter / X")
      expect(described_class.classify("x.com")).to eq("Twitter / X")
      expect(described_class.classify("t.co")).to eq("Twitter / X")
      expect(described_class.classify("producthunt.com")).to eq("Product Hunt")
      expect(described_class.classify("github.com")).to eq("GitHub")
      expect(described_class.classify("linkedin.com")).to eq("LinkedIn")
    end

    it "groups Google subdomains" do
      expect(described_class.classify("google.com")).to eq("Google")
      expect(described_class.classify("www.google.co.uk")).to eq("Google")
      expect(described_class.classify("news.google.com")).to eq("Google")
    end

    it "returns Other for unknown hosts" do
      expect(described_class.classify("somerandomblog.dev")).to eq("Other")
    end
  end

  describe ".known" do
    it "names the sites the rules know, and no other host" do
      expect([ described_class.known("www.news.ycombinator.com"), described_class.known("t.co"), described_class.known("google.de") ]).to eq([ "Hacker News", "Twitter / X", "Google" ])
      expect([ described_class.known("somerandomblog.dev"), described_class.known("openstage.dev"), described_class.known(nil) ]).to eq([ nil, nil, nil ])
    end

    it "names Gmail apart from Google, and an Android app as its site" do
      expect(%w[mail.google.com com.google.android.gm].map { |host| described_class.known(host) }).to eq(%w[Gmail Gmail])
      expect(%w[com.google.android.googlequicksearchbox news.google.com].map { |host| described_class.known(host) }).to eq(%w[Google Google])
      expect(%w[com.twitter.android com.reddit.frontpage com.linkedin.android].map { |host| described_class.known(host) }).to eq([ "Twitter / X", "Reddit", "LinkedIn" ])
    end
  end
end
