module Projects
  # The numbers a project draws on its builder's dashboard chart beside its
  # commits, switched in the dashboard's Your projects.
  class DashboardNumbersController < ApplicationController
    before_action :require_authentication

    def update
      repo = current_user.github_repos.find(params[:project_id])
      number = params[:number].presence_in(GithubRepo::DASHBOARD_NUMBERS)
      return redirect_to(dashboard_path, alert: "The dashboard cannot draw that.", status: :see_other) unless number

      on = ActiveModel::Type::Boolean.new.cast(params[:on])
      repo.update!(dashboard_numbers: on ? repo.dashboard_numbers | [ number ] : repo.dashboard_numbers - [ number ])
      redirect_to dashboard_path(anchor: "your-activity"), status: :see_other
    end
  end
end
