class PaymentFailedMailer < ApplicationMailer
  def notify(user)
    @user = user
    mail(
      to: "#{user.github_username}@users.noreply.github.com",
      subject: "Your Openstage Pro payment failed"
    )
  end
end
