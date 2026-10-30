# The Pro builder's numbers, for their page and each project's: the chart
# filter every chart page shares, with commits, site visits and Openstage's
# own visitors, views, new followers and clicks out, then the panels of
# their websites or of their pages on Openstage.
class AnalyticsController < ApplicationController
  before_action :require_authentication
  before_action :require_pro

  # The view asked for (Progress::Filter, old links too) renders first, with
  # the panels its URL names (AnalyticsHelper::PANELS); the page's script
  # asks Api::AnalyticsController for the others, and switches the panels
  # itself.
  def index
    filter = Progress::Filter.from_analytics(params)
    @panels = params[:panels].presence_in(AnalyticsHelper::PANELS.keys) || AnalyticsHelper::PANELS.keys.first
    @report = Analytics::ReportService.new(user: current_user, range: filter.range, show: filter.show, pages: filter.projects)
    return if @report.call

    redirect_to dashboard_path, alert: @report.errors.full_messages.to_sentence
  end

  private

  def require_pro
    return if current_user&.pro?

    redirect_to dashboard_path, alert: "Analytics is a Pro feature."
  end
end
