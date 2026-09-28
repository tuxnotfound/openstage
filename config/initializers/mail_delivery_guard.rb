# A process whose environment has no RESEND_API_KEY renders every mail and
# throws it away: perform_deliveries is false, raise_delivery_errors never
# fires, and nothing is logged. On 2026-09-28 the web process had the key and
# the Solid Queue worker did not, so every subscription confirmation the queue
# handled was silently discarded while the admin test mail worked.
#
# Interceptors run before the perform_deliveries check, so this sees the mails
# that are about to be dropped and names them.
module MailDeliveryGuard
  def self.delivering_email(message)
    return if ActionMailer::Base.perform_deliveries

    Rails.logger.warn(
      "[mail] DROPPED #{message.subject.inspect} to #{Array(message.to).join(', ')}: " \
      "deliveries are off in this process (RESEND_API_KEY missing?)."
    )
  end
end

ActionMailer::Base.register_interceptor(MailDeliveryGuard)

# Said once at boot, so the state is visible without waiting for a mail.
Rails.application.config.after_initialize do
  if Rails.env.production? && !ActionMailer::Base.perform_deliveries
    Rails.logger.warn("[mail] deliveries are OFF in this process: RESEND_API_KEY is missing. Mail will be rendered and discarded.")
  end
end
