class BadgesController < ApplicationController
  def show
    user = User.active.find_by(username: params[:username])
    return head :not_found unless user

    track_impression(user)

    entries_count = user.public_entries_count
    commits_count = user.public_github_commits_count
    message = "#{commits_count} commits | #{entries_count} entries"

    svg = Rails.cache.fetch(cache_key(user, entries_count, commits_count), expires_in: 10.minutes) do
      build_badge_svg(message)
    end

    expires_in 10.minutes, public: true
    send_data svg, type: "image/svg+xml", disposition: "inline"
  end

  private

  def track_impression(user)
    referrer = request.referer.present? ? (URI.parse(request.referer).host rescue nil) : nil
    ip_hash  = Digest::SHA256.hexdigest("#{request.remote_ip}#{Date.current}")
    user.badge_impressions.create!(
      kind:      "badge",
      viewed_at: Time.current,
      referrer:  referrer,
      ip_hash:   ip_hash
    )
  rescue ActiveRecord::ActiveRecordError
    # Don't break badge rendering if impression tracking fails.
  end

  def cache_key(user, entries_count, commits_count)
    ["profile-badge", user.id, user.updated_at.to_i, entries_count, commits_count].join(":")
  end

  def build_badge_svg(message)
    escaped = ERB::Util.html_escape(message)

    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="360" height="20" role="img" aria-label="openstage: #{escaped}">
        <title>openstage: #{escaped}</title>
        <linearGradient id="s" x2="0" y2="100%">
          <stop offset="0" stop-color="#fff" stop-opacity=".7"/>
          <stop offset=".1" stop-color="#aaa" stop-opacity=".1"/>
          <stop offset=".9" stop-opacity=".3"/>
          <stop offset="1" stop-opacity=".5"/>
        </linearGradient>
        <clipPath id="r">
          <rect width="360" height="20" rx="4" fill="#fff"/>
        </clipPath>
        <g clip-path="url(#r)">
          <rect width="94" height="20" fill="#0f172a"/>
          <rect x="94" width="266" height="20" fill="#15803d"/>
          <rect width="360" height="20" fill="url(#s)"/>
        </g>
        <g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" text-rendering="geometricPrecision" font-size="11">
          <text aria-hidden="true" x="48" y="15" fill="#010101" fill-opacity=".3">openstage</text>
          <text x="48" y="14">openstage</text>
          <text aria-hidden="true" x="226" y="15" fill="#010101" fill-opacity=".3">#{escaped}</text>
          <text x="226" y="14">#{escaped}</text>
        </g>
      </svg>
    SVG
  end
end
