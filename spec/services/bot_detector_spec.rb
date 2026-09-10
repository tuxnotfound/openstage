require "rails_helper"

RSpec.describe BotDetector do
  describe ".bot?" do
    it "flags the AI crawlers robots.txt welcomes by name" do
      [
        "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko); compatible; GPTBot/1.2; +https://openai.com/gptbot",
        "Mozilla/5.0 (compatible; ClaudeBot/1.0; +claudebot@anthropic.com)",
        "Mozilla/5.0 (compatible; PerplexityBot/1.0; +https://perplexity.ai/perplexitybot)",
        "Mozilla/5.0 (compatible; CCBot/2.0; https://commoncrawl.org/faq/)"
      ].each do |ua|
        expect(described_class).to be_bot(ua), "expected #{ua.inspect} to be treated as a bot"
      end
    end

    it "flags search, social and SEO crawlers" do
      [
        "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
        "Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)",
        "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)",
        "Mozilla/5.0 (compatible; AhrefsBot/7.0; +http://ahrefs.com/robot/)"
      ].each { |ua| expect(described_class).to be_bot(ua) }
    end

    it "flags scripted clients and headless browsers" do
      [ "curl/8.4.0", "python-requests/2.31.0", "Wget/1.21.4", "HeadlessChrome/120.0.0.0" ].each do |ua|
        expect(described_class).to be_bot(ua)
      end
    end

    it "treats a missing user agent as non-human" do
      expect(described_class).to be_bot(nil)
      expect(described_class).to be_bot("")
    end

    it "does not flag real browsers" do
      [
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0"
      ].each { |ua| expect(described_class).not_to be_bot(ua) }
    end
  end
end
