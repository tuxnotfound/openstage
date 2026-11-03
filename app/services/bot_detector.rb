module BotDetector
  # Named crawlers, including the AI agents public/robots.txt welcomes onto
  # profile pages by name, and the fetchers an AI assistant sends when someone
  # asks it about a page (ChatGPT-User, Claude-User, Perplexity-User), whose
  # user agents need not say bot. Without this filter they inflate
  # ProfileView, which is the metric Pro is sold on.
  NAMED = %w[
    gptbot oai-searchbot chatgpt-user claudebot claude-user claude-searchbot claude-web anthropic-ai
    perplexitybot perplexity-user google-extended google-cloudvertexbot meta-externalagent meta-externalfetcher
    mistralai-user duckassistbot youbot
    googlebot bingbot applebot yandexbot baiduspider duckduckbot slurp
    facebookexternalhit twitterbot linkedinbot slackbot discordbot telegrambot
    whatsapp pinterestbot redditbot
    ahrefsbot semrushbot mj12bot dotbot petalbot bytespider ccbot cohere-ai
    amazonbot imagesiftbot diffbot screaming
    curl wget python-requests python-urllib go-http-client okhttp axios
    postman insomnia headlesschrome phantomjs puppeteer playwright
    uptimerobot pingdom statuscake betteruptime
  ].freeze

  GENERIC = /\b(bot|crawler|spider|scraper|archiver|monitoring|preview)\b/i

  # Treats a blank user agent as non-human: real browsers always send one, and
  # under-counting is the honest failure mode for a metric we charge for.
  def self.bot?(user_agent)
    return true if user_agent.blank?

    normalized = user_agent.to_s.downcase
    return true if NAMED.any? { |name| normalized.include?(name) }

    GENERIC.match?(normalized)
  end
end
