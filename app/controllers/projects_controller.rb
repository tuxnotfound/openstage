# A project's words, website and picture as the builder wants them on their
# page. The builder's own win over GitHub's; a field left blank goes back to
# what GitHub says. Edited in place on the dashboard, in the project's row.
class ProjectsController < ApplicationController
  before_action :require_authentication

  def edit
    @repo = current_user.github_repos.find(params[:id])
  end

  def update
    @repo = current_user.github_repos.find(params[:id])
    return render(:edit, status: :unprocessable_entity) unless @repo.update(project_params)

    redirect_to dashboard_path, status: :see_other
  end

  private

  def project_params
    params.require(:github_repo).permit(:description_edit, :website_edit, :image_edit)
  end
end
