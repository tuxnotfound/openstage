# F2's two emails. Both rebuild the week when they are sent, from the builder's
# public entries only, so nothing private reaches a subscriber.
class WeeklyMailer < ApplicationMailer
  # The builder's own week, and one link: the week card editor. It never posts.
  def week_ready(user)
    @draft      = RecapDraft.for_user(user, days: 7)
    @card_url   = current_week_card_url(from: "weekly")
    @stop_url   = weekly_email_unsubscribe_url(token: user.signed_id(purpose: :weekly_email))
    one_click_unsubscribe(@stop_url)

    mail(to: user.email, subject: "Your week is ready to review")
  end

  # The week a subscriber asked for when they confirmed on the builder's page.
  def digest(subscription)
    @builder     = subscription.user
    @draft       = RecapDraft.for_user(@builder, days: 7)
    @profile_url = profile_url(@builder.username, ref: "digest")
    @home_url    = root_url(ref: "digest")
    @unsub_url   = unsubscribe_subscription_url(subscription.token)
    one_click_unsubscribe(@unsub_url)

    mail(to: subscription.email, subject: "What #{@builder.display_name} shipped this week")
  end

  private

  def one_click_unsubscribe(url)
    headers["List-Unsubscribe"] = "<#{url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
  end
end
