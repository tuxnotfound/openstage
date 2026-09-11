# Owner-only for now. C1 generalises this page to every user on the dashboard;
# building it owner-first is what unblocks the founder's own weekly dogfood,
# whose data only exists in production.
class RecapsController < ApplicationController
  before_action :require_owner

  WINDOWS = [ 7, 30, 90 ].freeze

  def show
    @days          = (params[:days].presence&.to_i).then { |d| WINDOWS.include?(d) ? d : 7 }
    @include_noise = params[:noise].present?
    @picks         = Array(params[:picks]).map(&:to_i)
    @draft         = build_draft
  end

  # C3, early: a Posted entry is only ever created from a URL the user pastes,
  # never inferred from a click, so every one of them is verifiable.
  def log_post
    url = params[:url].to_s.strip
    return redirect_to(recap_path, alert: "Paste the URL of your post first.") if url.blank?

    text  = params[:text].to_s.strip
    title = text.lines.first.to_s.strip.presence || "Shared a build-in-public recap"

    current_user.entries.create!(
      entry_type:  :posted,
      source:      :manual,
      title:       title.truncate(120),
      body:        text.presence,
      url:         url,
      occurred_at: Time.current
    )

    redirect_to recap_path, notice: "Logged. It's on your profile under Posted."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to recap_path, alert: "Could not log that: #{e.record.errors.full_messages.to_sentence}"
  end

  private

  def build_draft
    entries = current_user.entries
                          .publicly_visible
                          .where(occurred_at: @days.days.ago..)
                          .chronological

    RecapDraft.new(
      username:      current_user.username,
      items:         RecapDraft.from_entries(entries),
      days:          @days,
      include_noise: @include_noise
    )
  end

  def require_owner
    head :not_found unless current_user&.owner?
  end
end
