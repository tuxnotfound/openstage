require "open3"

module Backups
  # A dump of the database, shipped to R2 every night. The shared box is one disk, so the copy
  # must leave the box (HOSTING.md). It refuses to run without R2 rather than leave a copy on
  # the same disk and call it a backup. GitHub tokens and Stripe keys are in the dump encrypted,
  # and the keys that open them live only in the app's environment.
  class RunService < ApplicationService
    KEEP_REMOTE = 30
    PREFIX = "openstage/#{Rails.env}".freeze

    attr_reader :key

    validate :r2_configured

    private

    def execute
      dump = dump_database
      @key = R2Gateway.upload("#{PREFIX}/#{dump.basename}", dump.open("rb"))
      dump.delete
      prune_remote
    end

    def r2_configured
      errors.add(:base, "R2 is not configured, so nothing would leave the box") unless R2Gateway.configured?
    end

    # pg_dump's custom format is already compressed, and pg_restore reads it back.
    def dump_database
      target = Rails.root.join("tmp/#{Rails.env}-#{Time.current.utc.strftime("%Y%m%d-%H%M")}.dump")
      output, status = Open3.capture2e(connection_env, "pg_dump", "--format=custom", "--no-owner", "--file", target.to_s, database)
      raise "pg_dump failed: #{output}" unless status.success?

      target
    end

    def prune_remote
      R2Gateway.keys("#{PREFIX}/")[0...-KEEP_REMOTE].each { R2Gateway.remove(it) }
    end

    def connection_env
      { "PGHOST" => config[:host], "PGPORT" => config[:port]&.to_s,
        "PGUSER" => config[:username], "PGPASSWORD" => config[:password] }.compact
    end

    def database = config.fetch(:database)

    def config = ActiveRecord::Base.connection_db_config.configuration_hash
  end
end
