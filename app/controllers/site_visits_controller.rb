# The page views Openstage's script (public/v.js) sends from builders'
# websites. No session, cookie or CSRF token, so it skips everything
# ApplicationController does; it answers every request the same way, at once,
# whether the view counted or not.
class SiteVisitsController < ActionController::API
  # The script sends a token, the page's URL and, as a page loads, its
  # referrer; anything bigger is not from it.
  MAX_BODY = 8.kilobytes

  # A missing r (a view sent without the referrer) is not an empty one (a
  # visitor with no referrer), so it goes on as it came.
  def create
    SiteVisits::RecordService.new(token: payload["p"], url: payload["u"], referrer: payload["r"], origin: request.headers["Origin"],
                                  country: request.headers["CF-IPCountry"], ip: request.remote_ip, user_agent: request.user_agent).call
    head :no_content
  end

  private

  # The script sends JSON as text/plain, which a browser posts to another
  # site without asking first. Read no more than it would send, whatever
  # the request says its length is.
  def payload
    @payload ||= begin
      raw = request.body.read(MAX_BODY + 1).to_s
      body = raw.bytesize <= MAX_BODY ? JSON.parse(raw) : {}
      body.is_a?(Hash) ? body.transform_values(&:to_s) : {}
    rescue JSON::ParserError
      {}
    end
  end
end
