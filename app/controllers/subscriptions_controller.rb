# Email subscribe on public profiles and project pages. The builder owns the
# list; the visitor owns the address. Every reply to the form says the same
# thing so the form cannot be used to find out who is already subscribed to
# whom.
class SubscriptionsController < ApplicationController
  before_action :load_builder, only: :create
  # The token in the URL is the credential; a mail client's one-click POST
  # carries no session and so no CSRF token.
  skip_forgery_protection only: :unsubscribe

  def create
    return redirect_to(followed_page) if bot?

    service = Subscriptions::RequestService.new(user: @builder, github_repo: @project, email: params[:email])
    if service.call
      redirect_to followed_page, notice: "Check your inbox for a confirmation link."
    else
      redirect_to followed_page, alert: "That does not look like an email address."
    end
  end

  def confirm
    subscription = Subscription.find_by(token: params[:token])
    return redirect_to(root_path, alert: "That confirmation link is no longer valid.") unless subscription

    subscription.confirm!
    redirect_to page_of(subscription), notice: "Confirmed. You will get #{subscription.followed_name}'s updates."
  end

  def confirm_unsubscribe
    @subscription = Subscription.find_by(token: params[:token])
    redirect_to(root_path, notice: "Already unsubscribed.") unless @subscription
  end

  def unsubscribe
    subscription = Subscription.find_by(token: params[:token])
    page         = subscription && page_of(subscription)
    subscription&.destroy

    if page
      redirect_to page, notice: "Unsubscribed. No more email from this page."
    else
      redirect_to root_path, notice: "Already unsubscribed."
    end
  end

  private

  # project: one of the builder's repos, from a project's page.
  def load_builder
    @builder = User.active.find_by(username: params[:username])
    return head(:not_found) unless @builder

    @project = @builder.github_repos.find_by(id: params[:project]) if params[:project].present?
    head :not_found if params[:project].present? && @project.nil?
  end

  def followed_page
    page_for(@builder, @project)
  end

  def page_of(subscription)
    page_for(subscription.user, subscription.github_repo)
  end

  def page_for(builder, repo)
    repo ? project_page_path(builder.username, repo.name) : profile_path(builder.username)
  end

  # A filled honeypot or a crawler user agent is not a person.
  def bot?
    params[:website].present? || BotDetector.bot?(request.user_agent)
  end
end
