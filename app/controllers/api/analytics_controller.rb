module Api
  # The Pro analytics page for a window, the numbers drawn and the pages in
  # view (Progress::Filter, as analytics reads it), as the page's script asks
  # for it (AnalyticsViewSerializer). Only for the signed-in Pro builder,
  # about their own pages; not cached, as each visit changes it.
  class AnalyticsController < ApplicationController
    before_action :require_pro_builder

    def show
      filter = Progress::Filter.from_analytics(params)
      report = Analytics::ReportService.new(user: current_user, range: filter.range, show: filter.show, picked: filter.projects)
      return render(json: { error: report.errors.full_messages.to_sentence }, status: :unprocessable_entity) unless report.call

      render json: AnalyticsViewSerializer.new(report).to_json
    end

    private

    # A script asking answers in status codes, not redirects.
    def require_pro_builder
      return head(:unauthorized) unless user_signed_in?

      head(:forbidden) unless current_user.pro?
    end
  end
end
