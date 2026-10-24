# Times each page and endpoint for the heavy builder of script/perf/seed.rb:
# wall time, SQL count and time, response size, and with TOP=1 the slowest
# statements. Development mode, so rendering is slower than in production.
#   DATABASE_URL=postgres:///openstage_perf DEMO_USERNAME=heavy TOP=1 bin/rails runner script/perf/measure.rb [paths...]
abort "Refusing: run this on a scratch database whose name contains 'perf'." unless ActiveRecord::Base.connection.current_database.include?("perf")

require "benchmark"
user = User.find_by!(username: "heavy")
req = ActionDispatch::TestRequest.create(Rails.application.env_config)
key = Rails.application.config.session_options[:key]
req.cookie_jar.encrypted[key] = { value: { "session_id" => SecureRandom.hex(16), "user_id" => user.id } }
signed_cookie = Rack::Utils.escape(req.cookie_jar[key])

paths = ARGV.empty? ? %w[/ /heavy /heavy?range=all /heavy/project-1 /api/progress/heavy?range=12m /api/progress/heavy?range=all /dashboard /analytics /api/analytics?range=90d /feed] : ARGV
paths.each do |path|
  signed = path.start_with?("/dashboard", "/analytics", "/api/analytics")
  session = ActionDispatch::Integration::Session.new(Rails.application)
  session.host! "localhost"
  headers = { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh) Safari/605.1.15" }
  headers["HTTP_COOKIE"] = "#{key}=#{signed_cookie}" if signed
  session.get(path, headers: headers) # warm
  runs = 3.times.map do
    queries = []
    sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:name] == "SCHEMA" || payload[:cached]
      queries << [ payload[:sql], 0 ]
    end
    timing = ActiveSupport::Notifications.subscribe("sql.active_record") { |event| queries.last[1] = event.duration if queries.any? && !event.payload[:cached] && event.payload[:name] != "SCHEMA" }
    ms = Benchmark.realtime { session.get(path, headers: headers) } * 1000
    ActiveSupport::Notifications.unsubscribe(sub)
    ActiveSupport::Notifications.unsubscribe(timing)
    [ ms, queries, session.response.body.bytesize, session.response.status ]
  end
  ms = runs.map(&:first).sum / runs.size
  _, queries, bytes, status = runs.last
  sql_ms = queries.sum(&:last)
  puts format("%-34s %3d %7.0fms  %3d queries %6.0fms sql  %6.1fKB", path, status, ms, queries.size, sql_ms, bytes / 1024.0)
  queries.sort_by { |_, t| -t }.first(3).each { |sql, t| puts format("      %6.1fms  %s", t, sql.gsub(/\s+/, " ")[0, 150]) } if ENV["TOP"]
end
