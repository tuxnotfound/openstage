# Email subscribe on public profiles. The builder owns the list; the visitor
# owns the address. Every reply to the form says the same thing so the form
# cannot be used to find out who is already subscribed to whom.
class SubscriptionsController < ApplicationController
  before_action :load_builder, only: :create

  def create
    return redirect_to(profile_path(@builder.username)) if bot?

    subscription = @builder.subscriptions.find_or_initialize_by(email: params[:email])

    if subscription.new_record? && !subscription.valid?
      return redirect_to(profile_path(@builder.username), alert: "That does not look like an email address.")
    end

    if subscription.confirmation_due?
      subscription.confirmation_sent_at = Time.current
      subscription.save!
      SubscriptionMailer.confirm(subscription).deliver_later
    end

    redirect_to profile_path(@builder.username), notice: "Check your inbox for a confirmation link."
  end

  def confirm
    subscription = Subscription.find_by(token: params[:token])
    return redirect_to(root_path, alert: "That confirmation link is no longer valid.") unless subscription

    subscription.confirm!
    redirect_to profile_path(subscription.user.username), notice: "Confirmed. You will get #{subscription.user.display_name}'s updates."
  end

  # GET for the link in the mail, POST for List-Unsubscribe-Post clients.
  def unsubscribe
    subscription = Subscription.find_by(token: params[:token])
    builder      = subscription&.user
    subscription&.destroy

    if builder
      redirect_to profile_path(builder.username), notice: "Unsubscribed. No more email from this page."
    else
      redirect_to root_path, notice: "Already unsubscribed."
    end
  end

  private

  def load_builder
    @builder = User.active.find_by(username: params[:username])
    head :not_found unless @builder
  end

  # A filled honeypot or a crawler user agent is not a person.
  def bot?
    params[:website].present? || BotDetector.bot?(request.user_agent)
  end
end
