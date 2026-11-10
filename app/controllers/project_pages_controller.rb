# One project's page, /:username/:repo: what it is, how its commits move,
# and what shipped. Public, like the builder's page it belongs to, unless the
# builder hid the project: then it opens for them alone, as it would show.
class ProjectPagesController < ApplicationController
  include CountsPageViews

  def show
    @user = User.active.find_by(username: params[:username])
    return head(:not_found) unless @user

    @revealed = hidden_repo&.full_name
    filter = Progress::Filter.from(params, repo: false)
    service = Progress::FocusService.new(user: @user, slug: params[:project], range: filter.range, show: filter.show, reveal: @revealed)
    return redirect_to(profile_path(@user.username), alert: "That project is not on #{@user.display_name}'s page.") unless service.call

    @focus = service
    @view_ticket = view_ticket(@user, repo_name: service.project.repo)
  end

  private

  # The builder's own look at a project they hid; nil for anyone else.
  def hidden_repo
    return unless current_user == @user

    @user.github_repos.where(included: false).find { |repo| repo.name.casecmp?(params[:project]) }
  end
end
