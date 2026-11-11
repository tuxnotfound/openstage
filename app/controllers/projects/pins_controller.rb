module Projects
  # A project its builder pins to their stage, or unpins, from the
  # dashboard's table or its list of projects (back=list), which comes back
  # as it showed, every colour moved. A refusal comes back to the top of the
  # page, where its message shows and the pinned projects lead the table.
  class PinsController < ApplicationController
    before_action :require_authentication

    def update
      repo = current_user.github_repos.find(params[:project_id])
      service = PinService.new(repo: repo, pinned: ActiveModel::Type::Boolean.new.cast(params[:pinned]))
      return redirect_to(back(anchor: anchor), status: :see_other) if service.call

      redirect_to back, alert: service.errors.full_messages.to_sentence, status: :see_other
    end

    private

    def anchor
      params[:back] == "list" ? ProjectsTableSerializer::MORE_ANCHOR : "your-activity"
    end

    # The chart's view, and the list's (Progress::Listing::DASHBOARD).
    def back(anchor: nil)
      kept = params.permit(:range, :show, :projects, *Progress::Listing.names(Progress::Listing::DASHBOARD))
      dashboard_path(**kept.to_h.symbolize_keys.compact_blank, anchor: anchor)
    end
  end
end
