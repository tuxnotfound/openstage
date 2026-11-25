module Api
  # Where a project's site visits stand (SiteVisitsStatusSerializer), as the
  # page Set up site visits asks while it waits for the first visit. Only for
  # the signed-in builder, about their own project; not cached, as a visit
  # changes it.
  class SiteVisitsController < ApplicationController
    before_action :require_builder

    def show
      repo = current_user.github_repos.find(params[:project_id])
      render json: SiteVisitsStatusSerializer.new(SiteVisits::Setup.new(current_user, repo: repo)).to_json
    end

    private

    # A script asking answers in status codes, not redirects.
    def require_builder
      head(:unauthorized) unless user_signed_in?
    end
  end
end
