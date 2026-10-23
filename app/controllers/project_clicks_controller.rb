# The Visit and View on GitHub buttons on a project's page go through here,
# so a click is counted before the visitor leaves: /:username/:repo/visit and
# /:username/:repo/github. The address comes from the repo, never the URL.
class ProjectClicksController < ApplicationController
  def show
    user = User.active.find_by(username: params[:username])
    repo = user&.github_repos&.included_repos&.find_by("LOWER(name) = ?", params[:project].downcase)
    target = repo&.outbound_url(params[:to])
    return redirect_to(user ? project_page_path(user.username, params[:project]) : root_path) unless target

    record_click(user, repo)
    redirect_to target, allow_other_host: true
  end

  private

  def record_click(user, repo)
    return if current_user == user || BotDetector.bot?(request.user_agent)

    user.project_clicks.create!(repo_name: repo.full_name, kind: params[:to], clicked_at: Time.current,
                                ip_hash: Digest::SHA256.hexdigest("#{request.remote_ip}#{Date.current}"))
  end
end
