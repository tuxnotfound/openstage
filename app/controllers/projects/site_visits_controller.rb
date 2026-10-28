module Projects
  # A project's site visits, set on its builder's view: the source, and
  # which site Free counts. The switch that shows them on its page is one of
  # its numbers (NumbersController).
  class SiteVisitsController < ApplicationController
    before_action :require_authentication

    def update
      repo = current_user.github_repos.find(params[:project_id])
      service = SiteVisits::ConfigureService.new(repo: repo, source: params[:source].presence, count_here: params[:count_here].present?)
      flash_message = service.call ? { notice: "Site visits saved." } : { alert: service.errors.full_messages.to_sentence }

      # Back with the setup open, so a script just picked shows its line.
      redirect_to edit_project_path(repo, site: ("open" if params[:source].present?), anchor: "site-visits"),
                  status: :see_other, **flash_message
    end
  end
end
