module ApplicationHelper
  def tinyurl_for(url)
    Rails.cache.fetch("tinyurl_v2:#{url.hash.abs}", expires_in: 30.days) do
      response = Faraday.get("https://tinyurl.com/api-create.php") do |req|
        req.params[:url] = url
        req.options.timeout = 3
      end
      short = response.body.strip
      raise unless short.match?(/\Ahttps?:\/\/tinyurl\.com/)
      short
    end
  rescue
    url
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
