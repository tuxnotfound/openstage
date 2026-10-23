class SubscriptionMailer < ApplicationMailer
  def confirm(subscription)
    @subscription = subscription
    @builder      = subscription.user
    @project      = subscription.github_repo
    @page         = @project ? "openstage.dev/#{@builder.username}/#{@project.name}" : "openstage.dev/#{@builder.username}"
    @confirm_url  = confirm_subscription_url(subscription.token)
    @unsub_url    = unsubscribe_subscription_url(subscription.token)

    headers["List-Unsubscribe"] = "<#{@unsub_url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"

    what = @project ? "#{@project.name} updates from #{@builder.display_name}" : "updates from #{@builder.display_name}"
    mail(to: subscription.email, subject: "Confirm: #{what} on Openstage")
  end
end
