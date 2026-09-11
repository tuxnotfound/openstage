module ApplicationHelper
  # Never emit a user-supplied URL into an href without checking the scheme.
  # The model validates new input; this covers rows written before it existed.
  def safe_external_url(value)
    uri = URI.parse(value.to_s)
    value if %w[http https].include?(uri.scheme)
  rescue URI::InvalidURIError
    nil
  end

  # Builds the X share intent locally. This replaced a tinyurl_for helper that
  # called tinyurl.com from inside the dashboard's entry loop: its cache key was
  # "tinyurl_v2:#{url.hash}", and Ruby seeds String#hash per process, so the key
  # never repeated and the cache never hit. Every dashboard render made one
  # 3-second-timeout HTTP call per entry. Shortening bought nothing anyway,
  # since X wraps every link in t.co regardless.
  def share_on_x_url(entry, user)
    parts = [ entry.title ]
    parts << entry.body.truncate(100) if entry.body.present?
    parts << "#{profile_url(username: user.username)}#entry-#{entry.id}"

    "https://twitter.com/intent/tweet?text=#{CGI.escape(parts.join("\n\n"))}"
  end

  def streak_emoji(streak)
    case streak
    when 1    then "🐢"
    when 2..3 then "🌱"
    when 4..9 then "⚡"
    else
      fires = [streak / 10, 3].min
      streak >= 30 ? "🔥" * 3 + "🚀" : "🔥" * fires
    end
  end
end
