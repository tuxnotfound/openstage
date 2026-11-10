# The views Openstage's own pages send once they run in a browser
# (page_view_controller.js). No session, cookie or CSRF token: the signed
# ticket is the proof. It answers every request the same way, at once, whether
# the view counted or not.
class PageViewsController < ActionController::API
  def create
    PageViews::RecordService.new(ticket: params[:t], ip: request.remote_ip, user_agent: request.user_agent,
                                 country: request.headers["CF-IPCountry"]).call
    head :no_content
  end
end
