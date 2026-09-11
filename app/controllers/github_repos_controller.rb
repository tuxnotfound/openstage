class GithubReposController < ApplicationController
  before_action :require_authentication

  def update
    @repo = current_user.github_repos.find(params[:id])
    @repo.update!(included: params[:included] == "true")

    scope = current_user.entries.where(source: :github, repo_name: @repo.full_name)

    if !@repo.included?
      scope.update_all(hidden: true)
    elsif @repo.private_repo?
      # Including a private repo publishes its commit messages, which is the
      # point of the opt-in. Commit URLs stay stripped: they 404 for visitors
      # and only confirm the repo path.
      scope.update_all(hidden: false, url: nil)
    else
      scope.update_all(hidden: false)
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to dashboard_path }
    end
  end
end
