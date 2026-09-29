# Content Security Policy.
#
# The threat this closes is script injection. Profile pages render text that
# strangers wrote (bios, entry titles, recap posts), and until now a single
# escaping slip anywhere would have run as script in a visitor's browser. With
# this policy only scripts from our own origin, scripts carrying this
# response's nonce, and the analytics script can run.
#
# Deliberately left out:
# - form-action. Chrome applies it to the redirect that follows a form POST,
#   and two of ours leave the site by design: Sign in with GitHub and Stripe
#   Checkout. Guarding them would mean listing third-party hosts that can
#   change; the script rules above are what stop injected code.
# - Nonces on style-src. A nonce makes browsers ignore 'unsafe-inline', which
#   would break the few views that use style attributes. Styles cannot run code.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.script_src      :self, "https://cloud.umami.is"
    policy.connect_src     :self, "https://cloud.umami.is", "https://gateway.umami.is"
    policy.style_src       :self, :unsafe_inline
    policy.img_src         :self, :https, :data
    policy.font_src        :self, :data
    policy.object_src      :none
    policy.base_uri        :self
    policy.frame_ancestors :self
  end

  # A fresh nonce per response. Turbo compares head scripts with the nonce
  # stripped, so a Turbo visit does not re-run the importmap, and no view has
  # an executable inline script in the body; the JSON-LD blocks are data.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
