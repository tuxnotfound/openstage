module Api
  # The dashboard's Projects tab, as its script asks: a view of the list
  # (DashboardProjectsSerializer) when the builder searches it, changes its
  # view or its page, or once a switch saves; and one project's numbers
  # (DashboardLinesSerializer) when a click brings them in. Only for the
  # signed-in builder, about their own projects; never cached, so a saved
  # switch shows on the next read.
  class DashboardProjectsController < ApplicationController
    before_action :require_builder

    def index
      list = Projects::DashboardList.new(current_user, view: params[:view], query: params[:q], page: params[:page])
      render json: DashboardProjectsSerializer.new(list).to_json
    end

    def show
      repo = current_user.github_repos.find(params[:id])
      list = Projects::DashboardList.new(current_user)
      lines = Projects::Lines.new(repo, pins: (list.pinned_names if list.many?))
      render json: DashboardLinesSerializer.new(lines, color_class: list.color_class(repo)).to_json
    end

    private

    # A script asking answers in status codes, not redirects.
    def require_builder
      head(:unauthorized) unless user_signed_in?
    end
  end
end
