# One project's page, /:username/:repo: what it is, how its commits move,
# and what shipped. Public, like the builder's page it belongs to.
class ProjectPagesController < ApplicationController
  def show
    @user = User.active.find_by(username: params[:username])
    return head(:not_found) unless @user

    service = Progress::FocusService.new(user: @user, slug: params[:project], range: params[:range])
    return redirect_to(profile_path(@user.username), alert: "That project is not on #{@user.display_name}'s page.") unless service.call

    @focus = service
  end
end
