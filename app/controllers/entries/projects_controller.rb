module Entries
  # The dashboard's tag panel: one click puts an entry in a project, or says
  # it has none, then the panel redraws, still open.
  class ProjectsController < ApplicationController
    before_action :require_authentication

    def update
      entry = current_user.entries.find(params[:entry_id])
      service = TagService.new(entry: entry, repo_name: params[:repo_name], no_project: params[:no_project] == "1")
      return head(:unprocessable_entity) unless service.call

      # Back to the Entries tab, with the panel open.
      redirect_to dashboard_path(tab: "entries", tag: "1"), status: :see_other
    end
  end
end
