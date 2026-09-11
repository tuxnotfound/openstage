class PaymentFailedMailer < ApplicationMailer
  def notify(user)
    @user = user
    # Users who signed up before email capture have none. Returning without
    # calling mail() yields a NullMail, so deliver_later is a no-op rather
    # than a job that retries against an address that never existed.
    return message if user.email.blank?

    mail(to: user.email, subject: "Your Openstage Pro payment failed")
  end
end
