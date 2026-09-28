class SubscriptionMailer < ApplicationMailer
  def confirm(subscription)
    @subscription = subscription
    @builder      = subscription.user
    @confirm_url  = confirm_subscription_url(subscription.token)
    @unsub_url    = unsubscribe_subscription_url(subscription.token)

    headers["List-Unsubscribe"] = "<#{@unsub_url}>"

    mail(to: subscription.email, subject: "Confirm: updates from #{@builder.display_name} on Openstage")
  end
end
