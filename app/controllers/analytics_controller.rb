# The Pro builder's numbers, for their page and each project's: visitors, page
# views, new followers and clicks out, where visitors came from, and the links
# they followed.
class AnalyticsController < ApplicationController
  before_action :require_authentication
  before_action :require_pro

  # The view asked for renders first; the page's script asks
  # Api::AnalyticsController for the others.
  def index
    @report = Analytics::ReportService.new(user: current_user, range: params[:range], picked: Array(params[:pages]), metric: params[:metric])
    return if @report.call

    redirect_to dashboard_path, alert: @report.errors.full_messages.to_sentence
  end

  private

  def require_pro
    return if current_user&.pro?

    redirect_to dashboard_path, alert: "Analytics is a Pro feature."
  end
end
