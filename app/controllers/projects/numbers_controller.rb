module Projects
  # A number its builder shows a project's visitors, or hides from them:
  # from its numbers on the dashboard, by their script, and from the
  # project's own view (back=project).
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

    # Back where the switch was: the project's own view, or its numbers on
    # the dashboard.
    def back_to(repo)
      return edit_project_path(repo, anchor: "numbers") if params[:back] == "project"

      dashboard_path(project: repo.id)
    end
  end
end
