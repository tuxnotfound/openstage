# A process whose environment has no RESEND_API_KEY renders every mail and
# throws it away: perform_deliveries is false, raise_delivery_errors never
# fires, and nothing is logged. On 2026-09-28 the web process had the key and
# the Solid Queue worker did not, so every subscription confirmation the queue
# handled was silently discarded while the admin test mail worked.
#
# So a mail that cannot be sent is now an error rather than a shrug. From a
# job that means a failed execution, which is visible and can be retried once
# the environment is fixed; nothing is lost quietly. Interceptors run before
# the perform_deliveries check, so this sees the mail before it disappears.
#
# Deliveries are on in development and test, so this only fires where the
# environment is genuinely wrong.
module MailDeliveryGuard
  Error = Class.new(StandardError)

  def self.delivering_email(mail)
    return if ActionMailer::Base.perform_deliveries

    raise Error, "refusing to silently drop #{mail.subject.inspect} to #{Array(mail.to).join(', ')}: " \
                 "deliveries are off in this process (RESEND_API_KEY missing?)."
  end
end

ActionMailer::Base.register_interceptor(MailDeliveryGuard)

# Said once at boot, so the state is visible before the first mail fails.
# A warning, not a raise: a missing mail key must not keep the site down.
Rails.application.config.after_initialize do
  if Rails.env.production? && !ActionMailer::Base.perform_deliveries
    Rails.logger.warn("[mail] deliveries are OFF in this process: RESEND_API_KEY is missing. Every mail job will fail until it is set.")
  end
end
