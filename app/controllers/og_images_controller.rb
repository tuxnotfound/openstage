class OgImagesController < ApplicationController
  FALLBACK_PNG = [
    "89504E470D0A1A0A0000000D49484452000000010000000108060000001F15C4890000000A49444154789C6360000000020001E221BC330000000049454E44AE426082"
  ].pack("H*").b

  def show
    user = User.active.find_by(username: params[:username])
    return head :not_found unless user

    entries_count = user.entries.visible.count
    repos_count = user.github_repos.included_repos.count
    milestones_count = user.entries.visible.where(entry_type: :milestone).count

    cache_key = [
      "og-image",
      user.id,
      user.updated_at.to_i,
      entries_count,
      repos_count,
      milestones_count
    ].join(":")

    png = Rails.cache.fetch(cache_key, expires_in: 6.hours, race_condition_ttl: 10.seconds) do
      OgImageGenerator.call(
        user,
        entries_count: entries_count,
        repos_count: repos_count,
        milestones_count: milestones_count
      )
    end

    expires_in 1.hour, public: true
    send_data png, type: "image/png", disposition: "inline"
  rescue => e
    Rails.logger.error("[OgImagesController] OG generation failed for username=#{params[:username]}: #{e.class}: #{e.message}")
    expires_in 10.minutes, public: true
    send_data FALLBACK_PNG, type: "image/png", disposition: "inline"
  end
end
