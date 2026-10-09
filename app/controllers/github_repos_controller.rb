class GithubReposController < ApplicationController
  include GithubReposSection

  REFRESH_FAILED = "GitHub did not answer, so this list may be out of date.".freeze

  before_action :require_authentication
  rescue_from ApplicationGateway::Error, with: :github_unavailable

  # The repos section of Settings, rendered into its frame once the
  # Integrations tab shows it. It checks GitHub first, so private repos picked
  # or removed there show at once instead of at the next 2-hourly sync.
  def index
    return redirect_to(settings_path(tab: "integrations")) unless turbo_frame_request?

    refresh = GithubInstallations::RefreshService.new(user: current_user)
    note = REFRESH_FAILED if GithubAppGateway.configured? && !refresh.call
    render_section(note)
  end

  def update
    @repo = current_user.github_repos.find(params[:id])
    @repo.update!(included: params[:included] == "true", included_chosen: true)

    scope = current_user.entries.where(source: :github, repo_name: @repo.full_name)

    if !@repo.included?
      scope.update_all(hidden: true)
    elsif @repo.private_repo?
      # Including a private repo publishes its commit messages, which is the
      # point of the opt-in. Commit URLs stay stripped: they 404 for visitors
      # and only confirm the repo path.
      scope.update_all(hidden: false, url: nil)
    else
      scope.update_all(hidden: false)
    end

    # A repo never synced has no commits here yet, like a private repo just
    # connected: fetch them now, not at the next 2-hourly run.
    GithubSyncJob.perform_later(current_user.id) if @repo.included? && @repo.last_synced_at.nil?

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to dashboard_path }
    end
  end

  private

  def render_section(note)
    render partial: "settings/github_repos", locals: github_repos_section.merge(refresh: false, note: note)
  end

  def github_unavailable(error)
    Rails.error.report(error, handled: true)
    render_section(REFRESH_FAILED)
  end
end
