module ReferrerClassifier
  # Matched in order. An Android app sends its package as the referrer's
  # host (android-app://com.reddit.frontpage), so an app counts as its site,
  # and Gmail's mail as Gmail rather than as Google's search. Openstage's own
  # pages send visitors on to a project's website.
  RULES = [
    [ "Hacker News",   %w[news.ycombinator.com] ],
    [ "Reddit",        %w[reddit.com old.reddit.com new.reddit.com m.reddit.com com.reddit.frontpage] ],
    [ "Twitter / X",   %w[twitter.com x.com t.co mobile.twitter.com com.twitter.android] ],
    [ "Product Hunt",  %w[producthunt.com www.producthunt.com] ],
    [ "GitHub",        %w[github.com www.github.com] ],
    [ "LinkedIn",      %w[linkedin.com www.linkedin.com lnkd.in com.linkedin.android] ],
    [ "Mastodon",      %w[mastodon.social mastodon.online fosstodon.org hachyderm.io] ],
    [ "Bluesky",       %w[bsky.app] ],
    [ "Dev.to",        %w[dev.to] ],
    [ "Openstage",     %w[openstage.dev] ],
    [ "Gmail",         %w[mail.google.com com.google.android.gm] ],
    [ "Google",        :google_match ]
  ].freeze

  # A source as analytics' panels name it, on the builder's websites and on
  # their Openstage pages alike: the site's name when the rules know it,
  # else its host, lowercased, www. dropped; Direct for none. Never "Other",
  # which is what a ranked list leaves out.
  def self.label(host)
    return "Direct" if host.blank?

    known(host) || host.to_s.downcase.delete_prefix("www.")
  end

  # The name of a site the rules know, nil for any other host.
  def self.known(host)
    normalized = host.to_s.downcase.sub(/\Awww\./, "")
    RULES.each do |label, matcher|
      if matcher == :google_match
        return label if normalized.start_with?("google.") || normalized.include?(".google.")
      elsif matcher.include?(normalized) || matcher.include?(host.to_s.downcase)
        return label
      end
    end
    nil
  end
end
