class EntryClicksController < ApplicationController
  def show
    entry = Entry.publicly_visible.find_by(id: params[:id])

    if entry.nil? || entry.url.blank?
      redirect_to root_path
      return
    end

    # Validate URL scheme to prevent open-redirect to non-http(s) schemes.
    begin
      uri = URI.parse(entry.url)
      unless %w[http https].include?(uri.scheme)
        redirect_to root_path
        return
      end
    rescue URI::InvalidURIError
      redirect_to root_path
      return
    end

    # Record the click, skipping the entry owner's own clicks.
    unless current_user == entry.user
      ip_hash = Digest::SHA256.hexdigest("#{request.remote_ip}#{Date.current}")
      EntryClick.create!(
        user:       entry.user,
        entry:      entry,
        ip_hash:    ip_hash,
        clicked_at: Time.current
      )
    end

    redirect_to entry.url, allow_other_host: true
  end
end
