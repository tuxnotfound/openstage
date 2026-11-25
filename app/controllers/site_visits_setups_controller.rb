# Set up site visits: one page, three steps, from a project and its website
# to its first counted visit (SiteVisits::Setup). Every "Set up site visits"
# in the app leads here, with its project when the link knows it. Continue
# keeps the website and picks Openstage's script; a refusal shows in the
# first step, in the service's words. Its script draws the steps
# (SiteSetupIsland) and hears the first visit (Api::SiteVisitsController).
# "Edit setup" and Off stay on the project's own view.
class SiteVisitsSetupsController < ApplicationController
  before_action :require_authentication

  def show
    @setup = SiteVisits::Setup.new(current_user, project_id: params[:project])
  end

  def update
    repo = current_user.github_repos.find(params[:project_id])
    service = SiteVisits::SetUpService.new(repo: repo, website: params[:website].to_s)
    return redirect_to(site_visits_setup_path(project: repo.id), status: :see_other) if service.call

    @setup = SiteVisits::Setup.new(current_user, repo: repo, change: true)
    @website = params[:website].to_s
    @refusal = service.errors.full_messages.join(" ")
    render :show, status: :unprocessable_content
  end
end
