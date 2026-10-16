module ProgressHelper
  # The page's own params that the progress section and the timeline share.
  PROGRESS_PARAMS = %i[range offset repo chart filter].freeze
  RANGES = { "week" => "Week", "month" => "Month", "year" => "Year", "all" => "All" }.freeze

  # This page with some of its params changed; nil drops one.
  def progress_view_path(user, **changes)
    kept = params.permit(*PROGRESS_PARAMS).to_h.symbolize_keys
    profile_path(user.username, **kept.merge(changes).compact_blank)
  end

  # "+3", "−2" or "±0" against the period before, and whether it went up;
  # nil without one.
  def progress_delta(current, previous)
    return if previous.nil?

    change = current - previous
    text = if change.positive? then "+#{change}" elsif change.negative? then "−#{change.abs}" else "±0" end
    [ text, change.positive? ]
  end

  def progress_run_in(item, section)
    names = section.tally.projects.all.map(&:name)
    Progress::RunIn.capped(Progress::RunIn.of(item.title, item.body, names))
  end
end
