module AnalyticsHelper
  # The analytics page with some of its params changed; nil drops one.
  def analytics_view_path(**changes)
    kept = params.permit(:range, pages: [], show: []).to_h.symbolize_keys
    analytics_path(**kept.merge(changes).compact_blank)
  end

  # A page switch's link: the selection with that page switched. With every
  # page in view, switching one leaves the others; none left means all of them.
  def analytics_chip_path(report, page)
    keys = report.selected.map(&:key)
    keys = keys.include?(page.key) ? keys - [ page.key ] : keys + [ page.key ]
    analytics_view_path(pages: keys.empty? || keys.size == report.pages.size ? nil : keys)
  end

  # A number's link: the numbers charted with that one switched; the last one
  # stays, and the ones charted by default mean no param.
  def analytics_numbers_path(report, metric)
    now = report.metrics
    picked = now.include?(metric) ? now - [ metric ] : Analytics::CountService::METRICS & (now + [ metric ])
    picked = now if picked.empty?
    analytics_view_path(show: picked == Analytics::ReportService::CHARTED ? nil : picked)
  end

  # ["▲", "22%", true], ["±", "0%", nil] for no change, or nils when there is
  # nothing to compare with. up: nil leaves it uncoloured.
  def analytics_change(change)
    return [ nil, nil, nil ] if change.nil?
    return [ "±", "0%", nil ] if change.zero?

    [ change.negative? ? "▼" : "▲", "#{change.abs}%", change.positive? ]
  end

  def analytics_tone(up)
    { true => "text-up", false => "text-down" }[up]
  end
end
