# Rails::Rack::Logger writes every request's "Started" line at info, with the
# visitor's IP address (request.remote_ip, which cloudflare_proxies.rb walks
# back to the visitor), and the host keeps that log. Openstage's script posts
# each page view on a builder's website to /v, and the privacy page says
# Openstage does not keep those visitors' addresses, so these requests log
# warnings and errors only. Rails 8 does the same with
# Rails::Rack::SilenceRequest.
class SiteVisitsLogSilence
  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless env["REQUEST_METHOD"] == "POST" && env["PATH_INFO"] == "/v"

    Rails.logger.silence(Logger::WARN) { @app.call(env) }
  end
end

Rails.application.config.middleware.insert_before Rails::Rack::Logger, SiteVisitsLogSilence
