module Api
  # A tab of the analytics page (Analytics::Tab) for a window, the numbers
  # drawn and the pages in view (Progress::Filter, as analytics reads it), as
  # the page's script asks for it (AnalyticsViewSerializer). Only for the
  # signed-in builder, about their own pages, on a tab their plan opens; not
  # cached, as each visit changes it.
  class AnalyticsController < ApplicationController
    before_action :require_builder

    def show
      tab = Analytics::Tab.find(params[:tab])
      return head(:forbidden) unless tab.opens?(current_user)

      filter = Progress::Filter.from_analytics(params)
      report = Analytics::ReportService.new(user: current_user, tab: tab, range: filter.range, show: filter.show, pages: filter.projects)
      return render(json: { error: report.errors.full_messages.to_sentence }, status: :unprocessable_entity) unless report.call

      render json: AnalyticsViewSerializer.new(report).to_json
    end

    private

    # A script asking answers in status codes, not redirects.
    def require_builder
      head(:unauthorized) unless user_signed_in?
    end
  end
end
