# A project as its builder sees it: whether their page shows it, the numbers
# its page shows and where its site visits come from, and its words, website
# and picture. The builder's own words win over GitHub's; a field left blank
# goes back to what GitHub says.
class ProjectsController < ApplicationController
  before_action :require_authentication
  before_action :load_repo

  def edit
    render_overview
  end

  def update
    return redirect_to(edit_project_path(@repo), notice: "#{@repo.name} saved.", status: :see_other) if @repo.update(project_params)

    render_overview(status: :unprocessable_entity)
  end

  private

  def load_repo
    @repo = current_user.github_repos.find(params[:id])
  end

  def render_overview(status: :ok)
    @overview = Projects::GatherService.new(repo: @repo)
    return render(:edit, status: status) if @overview.call

    redirect_to dashboard_path, alert: @overview.errors.full_messages.to_sentence
  end

  def project_params
    params.require(:github_repo).permit(:description_edit, :website_edit, :image_edit)
  end
end
