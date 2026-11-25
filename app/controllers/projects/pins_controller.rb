module Projects
  # A project its builder pins to their stage, or unpins, from its numbers on
  # the dashboard, whose script reads the colours again; without it the
  # dashboard comes back with them open. A refusal says why.
  class PinsController < ApplicationController
    before_action :require_authentication

    def update
      repo = current_user.github_repos.find(params[:project_id])
      service = PinService.new(repo: repo, pinned: ActiveModel::Type::Boolean.new.cast(params[:pinned]))
      saved = service.call
      respond_to do |format|
        # The dashboard's Projects tab, which reads its colours again.
        format.json { saved ? head(:no_content) : render(json: { error: service.errors.full_messages.to_sentence }, status: :unprocessable_content) }
        format.html { redirect_to dashboard_path(project: repo.id), status: :see_other, alert: (service.errors.full_messages.to_sentence unless saved) }
      end
    end
  end
end
