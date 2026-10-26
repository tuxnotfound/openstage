module Projects
  # A project's site visits, set on its builder's view: the source, the
  # switch that shows them on its page, and which site Free counts.
  class SiteVisitsController < ApplicationController
    before_action :require_authentication

    def update
      repo = current_user.github_repos.find(params[:project_id])
      service = SiteVisits::ConfigureService.new(repo: repo, source: params[:source].presence, shown: shown,
                                                 count_here: params[:count_here].present?)
      flash_message = service.call ? { notice: "Site visits saved." } : { alert: service.errors.full_messages.to_sentence }

      # Back with the setup open, so a script just picked shows its line.
      redirect_to edit_project_path(repo, site: ("open" if params[:source].present?), anchor: "site-visits"),
                  status: :see_other, **flash_message
    end

    private

    def shown
      ActiveModel::Type::Boolean.new.cast(params[:shown]) if params.key?(:shown)
    end
  end
end
