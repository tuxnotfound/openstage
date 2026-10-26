module Projects
  # A number switched on or off for a project on its builder's dashboard
  # chart, from the table under it: by the chart's script, which then asks
  # for the chart again, or by the table's form without it.
  class DashboardNumbersController < ApplicationController
    before_action :require_authentication

    def update
      repo = current_user.github_repos.find(params[:project_id])
      number = params[:number].presence_in(GithubRepo::CHART_NUMBERS)
      return refuse unless number

      on = ActiveModel::Type::Boolean.new.cast(params[:on])
      repo.update!(dashboard_hidden: on ? repo.dashboard_hidden - [ number ] : repo.dashboard_hidden | [ number ])
      respond_to do |format|
        format.json { head :no_content }
        format.html { redirect_to dashboard_path(anchor: "your-activity"), status: :see_other }
      end
    end

    private

    def refuse
      respond_to do |format|
        format.json { head :unprocessable_entity }
        format.html { redirect_to dashboard_path, alert: "The dashboard cannot draw that.", status: :see_other }
      end
    end
  end
end
