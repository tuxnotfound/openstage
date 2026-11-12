# The stage a GitHub user would get, built from their public work for a
# visitor who has not signed in (Previews::BuildService), with the sign-in
# that claims it, tagged preview. Each preview reads GitHub on Openstage's
# own token, so bots get none, a visitor gets a few an hour, and search
# keeps none: a preview is a page about someone who never asked for one.
class PreviewsController < ApplicationController
  # Previews one visitor may open in an hour, and all visitors together, so a
  # flood cannot spend the token's hourly allowance.
  PER_VISITOR = 20
  PER_HOUR = 400

  before_action :keep_out_of_search
  before_action :refuse_bots, only: :show

  rescue_from ApplicationGateway::Error, with: :github_unavailable

  # The landing's form: the username typed, with or without its @, or any
  # GitHub address pasted, as the preview's own address. A repo's address,
  # or a profile's tab, gives its owner.
  def new
    @login = params[:github].to_s.strip.sub(%r{\A(?:https?://)?(?:www\.)?github\.com/}i, "").delete_prefix("@").split(%r{[/?#]}).first.to_s
    return redirect_to(root_path) if @login.blank?
    return render(:missing, status: :unprocessable_content) unless @login.match?(Previews::BuildService::LOGIN)

    redirect_to preview_path(@login)
  end

  # A member's GitHub account opens their stage, not a preview of it.
  def show
    @login = params[:login]
    member = User.active.with_github_login(@login).first
    return redirect_to(profile_path(member.username)) if member
    return render(:unavailable, status: :too_many_requests) if (@busy = throttled?)
    return render(:unavailable, status: :service_unavailable) unless GithubProfileGateway.configured?

    service = Previews::BuildService.new(login: @login, today: Date.current)
    return render(:missing, status: :not_found) unless service.call

    @preview = service.preview
    count_preview
  end

  private

  def keep_out_of_search
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
  end

  def refuse_bots
    head :not_found if BotDetector.bot?(request.user_agent)
  end

  # Counted before the cache answers: a reload costs GitHub nothing, but
  # counting it keeps the rule one line.
  def throttled?
    hour = Time.current.strftime("%Y%m%d%H")
    visitor = Digest::SHA256.hexdigest(request.remote_ip.to_s)
    over?("previews/#{hour}", PER_HOUR) | over?("previews/#{hour}/#{visitor}", PER_VISITOR)
  end

  def over?(key, limit)
    count = Rails.cache.read(key).to_i + 1
    Rails.cache.write(key, count, expires_in: 1.hour)
    count > limit
  end

  # Once per login a visitor previews, by the tag they first came with, as
  # sign-in starts are counted (SignIns::CountStartService). A member's own
  # look is never counted.
  def count_preview
    return if user_signed_in? || session[:previewed] == @login.downcase

    session[:previewed] = @login.downcase
    Event.track("preview", detail: session[:signup_ref].presence || SignIns::CountStartService::UNTAGGED)
  end

  def github_unavailable(error)
    Rails.error.report(error, handled: true)
    render :unavailable, status: :service_unavailable
  end
end
