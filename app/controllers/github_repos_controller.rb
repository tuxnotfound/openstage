class GithubReposController < ApplicationController
  before_action :require_authentication

  def update
    @repo = current_user.github_repos.find(params[:id])
    @repo.update!(included: params[:included] == "true")

    if @repo.included?
      current_user.entries.where(source: :github, repo_name: @repo.full_name).update_all(hidden: false)
    else
      current_user.entries.where(source: :github, repo_name: @repo.full_name).update_all(hidden: true)
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to dashboard_path }
    end
  end
end
