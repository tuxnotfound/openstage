module ReferrerClassifier
  RULES = [
    [ "Hacker News",   %w[news.ycombinator.com] ],
    [ "Reddit",        %w[reddit.com old.reddit.com new.reddit.com m.reddit.com] ],
    [ "Twitter / X",   %w[twitter.com x.com t.co mobile.twitter.com] ],
    [ "Product Hunt",  %w[producthunt.com www.producthunt.com] ],
    [ "GitHub",        %w[github.com www.github.com] ],
    [ "LinkedIn",      %w[linkedin.com www.linkedin.com lnkd.in] ],
    [ "Mastodon",      %w[mastodon.social mastodon.online fosstodon.org hachyderm.io] ],
    [ "Bluesky",       %w[bsky.app] ],
    [ "Dev.to",        %w[dev.to] ],
    [ "Google",        :google_match ]
  ].freeze

  def self.classify(host)
    return "Direct" if host.blank?

    normalized = host.to_s.downcase.sub(/\Awww\./, "")
    RULES.each do |label, matcher|
      if matcher == :google_match
        return label if normalized.start_with?("google.") || normalized.include?(".google.")
      elsif matcher.include?(normalized) || matcher.include?(host.to_s.downcase)
        return label
      end
    end
    "Other"
  end
end
