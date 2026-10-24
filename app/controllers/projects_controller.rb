# A project's words, website and picture as the builder wants them on their
# page. The builder's own win over GitHub's; a field left blank goes back to
# what GitHub says. Edited on a page of its own, laid out like the project's.
class ProjectsController < ApplicationController
  before_action :require_authentication
  before_action :load_repo

  def edit
  end

  def update
    return render(:edit, status: :unprocessable_entity) unless @repo.update(project_params)

    redirect_to dashboard_path, notice: "#{@repo.name} saved.", status: :see_other
  end

  private

  # The project, for its colour; nil for a repo with nothing public yet.
  def load_repo
    @repo = current_user.github_repos.find(params[:id])
    @project = Progress::Projects.new(current_user.entries.publicly_visible.without_tooling_noise).find(@repo.full_name)
  end

  def project_params
    params.require(:github_repo).permit(:description_edit, :website_edit, :image_edit)
  end
end
