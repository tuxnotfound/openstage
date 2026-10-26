# The page views Openstage's script (public/v.js) sends from builders'
# websites. No session, cookie or CSRF token, so it skips everything
# ApplicationController does; it answers every request the same way, at once,
# whether the view counted or not.
class SiteVisitsController < ActionController::API
  # The script sends a token and a URL; anything bigger is not from it.
  MAX_BODY = 4.kilobytes

  def create
    SiteVisits::RecordService.new(token: payload["p"], url: payload["u"], origin: request.headers["Origin"],
                                  ip: request.remote_ip, user_agent: request.user_agent).call
    head :no_content
  end

  private

  # The script sends JSON as text/plain, which a browser posts to another
  # site without asking first.
  def payload
    @payload ||= begin
      body = request.content_length.to_i <= MAX_BODY ? JSON.parse(request.raw_post.to_s) : {}
      body.is_a?(Hash) ? body.transform_values(&:to_s) : {}
    rescue JSON::ParserError
      {}
    end
  end
end
