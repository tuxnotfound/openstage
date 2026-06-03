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
end
