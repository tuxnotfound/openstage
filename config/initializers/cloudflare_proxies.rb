# Every request reaches Render through Cloudflare, so the nearest untrusted
# address in X-Forwarded-For was a Cloudflare edge and request.remote_ip
# stopped there: unique visitors were counted per edge, not per person
# (BUGS.md, 2026-10-20). Trusting Cloudflare's published ranges as proxies
# lets remote_ip walk past them to the visitor. Nobody else can send from
# these ranges, so a forged header still ends at the forger's own address.
#
# Ranges from https://www.cloudflare.com/ips, read 2026-10-23. Cloudflare
# rarely changes them; a new range would show as edge addresses again.
CLOUDFLARE_RANGES = %w[
  173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 141.101.64.0/18
  108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 197.234.240.0/22 198.41.128.0/17
  162.158.0.0/15 104.16.0.0/13 104.24.0.0/14 172.64.0.0/13 131.0.72.0/22
  2400:cb00::/32 2606:4700::/32 2803:f800::/32 2405:b500::/32 2405:8100::/32
  2a06:98c0::/29 2c0f:f248::/32
].freeze

Rails.application.config.action_dispatch.trusted_proxies =
  ActionDispatch::RemoteIp::TRUSTED_PROXIES + CLOUDFLARE_RANGES.map { |range| IPAddr.new(range) }
