module AnalyticsHelper
  def delta_badge(delta)
    return "" if delta.nil?

    pct = delta[:pct]
    if pct.nil?
      content_tag(:span, "new", class: "ml-2 inline-flex items-center text-[10px] font-medium text-gray-500 bg-gray-100 px-1.5 py-0.5 rounded")
    else
      tone = pct.positive? ? "text-emerald-700 bg-emerald-50" : pct.negative? ? "text-rose-700 bg-rose-50" : "text-gray-500 bg-gray-100"
      arrow = pct.positive? ? "↑" : pct.negative? ? "↓" : "·"
      content_tag(:span, "#{arrow} #{pct.abs}%",
                  class: "ml-2 inline-flex items-center text-[10px] font-medium #{tone} px-1.5 py-0.5 rounded",
                  title: "Prior period: #{delta[:prior]}")
    end
  end

  # GitHub-style intensity bucket: 0..4 based on share of max.
  def heatmap_level(count, max)
    return 0 if count.zero?
    return 1 if max <= 1
    share = count.to_f / max
    return 4 if share >= 0.75
    return 3 if share >= 0.5
    return 2 if share >= 0.25
    1
  end

  def heatmap_fill(level)
    case level
    when 4 then "#4338ca"
    when 3 then "#6366f1"
    when 2 then "#a5b4fc"
    when 1 then "#e0e7ff"
    else "#f3f4f6"
    end
  end
end
