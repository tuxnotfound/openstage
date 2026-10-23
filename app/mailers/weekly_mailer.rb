# F2's two emails. Both show the Week view of the builder's progress section
# as it stands when they are sent, from public entries only, so nothing
# private reaches a subscriber and the page they link to says the same.
class WeeklyMailer < ApplicationMailer
  helper :progress

  # The builder's own week, and one link: its card. It never posts.
  def week_ready(user)
    @section    = week_of(user)
    @card_url   = current_week_card_url(from: "weekly")
    @log_url    = dashboard_url
    @stop_url   = weekly_email_unsubscribe_url(token: user.signed_id(purpose: :weekly_email))
    one_click_unsubscribe(@stop_url)

    mail(to: user.email, subject: "Your week is ready to review")
  end

  # The week a subscriber asked for when they confirmed on the builder's page.
  def digest(subscription)
    @builder     = subscription.user
    @section     = week_of(@builder)
    @profile_url = profile_url(@builder.username, range: "week", ref: "digest")
    @home_url    = root_url(ref: "digest")
    @unsub_url   = unsubscribe_subscription_url(subscription.token)
    one_click_unsubscribe(@unsub_url)

    mail(to: subscription.email, subject: "#{@builder.display_name}'s week on Openstage")
  end

  private

  def week_of(user)
    Progress::ComposeService.new(user: user, range: "week").tap(&:call!).section
  end

  def one_click_unsubscribe(url)
    headers["List-Unsubscribe"] = "<#{url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
  end
end
