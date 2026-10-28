module Projects
  # A number its builder shows a project's visitors, or hides from them:
  # from the dashboard's table, by the chart's script (which then asks for
  # the chart again) or by its form without it, and from the project's own
  # view (back=project).
  class NumbersController < ApplicationController
    before_action :require_authentication

    def update
      repo = current_user.github_repos.find(params[:project_id])
      service = ShowNumberService.new(repo: repo, number: params[:number].to_s, shown: shown)
      return refuse(repo) unless service.call

      respond_to do |format|
        format.json { head :no_content }
        format.html { redirect_to back_to(repo), status: :see_other }
      end
    end

    private

    def shown
      ActiveModel::Type::Boolean.new.cast(params[:shown]) if params.key?(:shown)
    end

    def refuse(repo)
      respond_to do |format|
        format.json { head :unprocessable_entity }
        format.html { redirect_to back_to(repo), alert: "That number cannot be switched.", status: :see_other }
      end
    end

    # Back where the switch was: the project's own view, or the dashboard's
    # chart as it showed.
    def back_to(repo)
      return edit_project_path(repo, anchor: "numbers") if params[:back] == "project"

      dashboard_path(**params.permit(:range, :show, :projects).to_h.symbolize_keys.compact_blank, anchor: "your-activity")
    end
  end
end
