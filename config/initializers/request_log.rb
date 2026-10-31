# Openstage's request log keeps no visitor's IP address. Rails::Rack::Logger
# writes every request's "Started" line at info with request.remote_ip, which
# cloudflare_proxies.rb walks back to the visitor, and the host keeps that
# log. RequestLogger writes the same line, under the same tags, without it.
class RequestLogger < Rails::Rack::Logger
  private

  # Started GET "/session/new" at 2012-09-26 14:51:42 -0700
  def started_request_message(request)
    sprintf('Started %s "%s" at %s', request.raw_request_method, request.filtered_path, Time.now)
  end
end

# Openstage's script posts every page view on every builder's website to /v,
# far more requests than the rest of the app gets, so those log warnings and
# errors only. Rails 8 does the same with Rails::Rack::SilenceRequest.
class SiteVisitsLogSilence
  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless env["REQUEST_METHOD"] == "POST" && env["PATH_INFO"] == "/v"

    Rails.logger.silence(Logger::WARN) { @app.call(env) }
  end
end

# In this order: the silencer goes before the logger it silences, which has to
# be in the stack by then.
Rails.application.config.middleware.swap Rails::Rack::Logger, RequestLogger, Rails.application.config.log_tags
Rails.application.config.middleware.insert_before RequestLogger, SiteVisitsLogSilence
