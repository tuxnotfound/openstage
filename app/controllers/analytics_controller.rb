# A builder's analytics, a tab at a time (Analytics::Tab): the chart filter
# every chart page shares, with the tab's numbers for their stage and each
# project, then the tab's lists. Free opens three of the tabs, with its own
# numbers alone; a tab it does not open shows the Go Pro view.
class AnalyticsController < ApplicationController
  before_action :require_authentication
  before_action :follow_old_panels

  # The view asked for (Progress::Filter, old links too) renders first; the
  # page's script asks Api::AnalyticsController for the others, and a tab is
  # a page of its own.
  def index
    @tab = Analytics::Tab.find(params[:tab])
    return unless @tab.opens?(current_user)

    filter = Progress::Filter.from_analytics(params)
    @report = Analytics::ReportService.new(user: current_user, tab: @tab, range: filter.range, show: filter.show, pages: filter.projects)
    return if @report.call

    redirect_to dashboard_path, alert: @report.errors.full_messages.to_sentence
  end

  private

  # The switch to Openstage's own lists is the Openstage views tab now.
  def follow_old_panels
    return unless params[:panels] == "openstage" && params[:tab].blank?

    redirect_to analytics_path(request.query_parameters.except("panels").merge("tab" => "openstage"))
  end
end
