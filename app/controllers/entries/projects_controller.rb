module Entries
  # The progress section's tag panel: one click puts an entry in a project, or
  # says it has none, then the section redraws on the builder's page.
  class ProjectsController < ApplicationController
    before_action :require_authentication

    def update
      entry = current_user.entries.find(params[:entry_id])
      service = TagService.new(entry: entry, repo_name: params[:repo_name], no_project: params[:no_project] == "1")
      return head(:unprocessable_entity) unless service.call

      redirect_to profile_path(current_user.username, **back_params), status: :see_other
    end

    private

    # Back to the period and view the click came from, with the panel open.
    def back_params
      params.permit(:range, :offset, :repo, :chart, repo: []).to_h.symbolize_keys.merge(tag: "1").compact_blank
    end
  end
end
