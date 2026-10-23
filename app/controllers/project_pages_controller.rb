# One project's page, /:username/:repo: what it is, how its commits move,
# and what shipped. Public, like the builder's page it belongs to.
class ProjectPagesController < ApplicationController
  def show
    @user = User.active.find_by(username: params[:username])
    return head(:not_found) unless @user

    service = Progress::FocusService.new(user: @user, slug: params[:project], range: params[:range])
    return redirect_to(profile_path(@user.username), alert: "That project is not on #{@user.display_name}'s page.") unless service.call

    @focus = service
    record_view
  end

  private

  # Counted for later, shown nowhere yet: never the builder's own visit, never
  # a bot's. The IP is hashed with the day, as on the builder's page.
  def record_view
    return if current_user == @user || BotDetector.bot?(request.user_agent)

    @user.project_views.create!(
      repo_name: @focus.project.repo,
      viewed_at: Time.current,
      referrer:  referrer_host,
      ip_hash:   Digest::SHA256.hexdigest("#{request.remote_ip}#{Date.current}"),
      # CF-IPCountry is set by Cloudflare (e.g. "US", "GB"); nil without it.
      country:   request.headers["CF-IPCountry"].presence
    )
  end

  def referrer_host
    URI.parse(request.referer).host if request.referer.present?
  rescue URI::InvalidURIError
    nil
  end
end
