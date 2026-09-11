class ApplicationMailer < ActionMailer::Base
  # openstage.dev has no MX record, so replies to the From address would bounce.
  # Reply-To points at a mailbox that actually receives.
  default from: ENV.fetch("MAIL_FROM", "Openstage <hello@openstage.dev>"),
          reply_to: ENV.fetch("MAIL_REPLY_TO", "tuxnotfound@cioga.eu")

  layout "mailer"
end
