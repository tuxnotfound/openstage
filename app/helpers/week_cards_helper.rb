# Layout for the week card's SVG. The card is 1200x675 and is drawn on the
# server, so the editor's preview and the downloaded PNG are the same picture.
module WeekCardsHelper
  CARD = { ground: "#0C2A4D", line: "#8FD3FF", text: "#F2F7FC", muted: "#A9C3DE", quiet: "#6F8BAA" }.freeze
  CARD_LEFT = 52
  CARD_RIGHT = 1148
  BAR_HEIGHT = 150
  # Thin weeks keep honest bars: one commit never stands taller than this.
  BAR_PER_COMMIT = 10

  def card_columns(days)
    width = (CARD_RIGHT - CARD_LEFT).to_f / days.size
    days.each_with_index.map { |day, i| { day: day, cx: (CARD_LEFT + (width * (i + 0.5))).round, width: width } }
  end

  def card_bar_scale(days)
    most = days.map(&:total).max.to_i
    most.zero? ? 0 : [ BAR_HEIGHT.to_f / most, BAR_PER_COMMIT ].min
  end

  # Bottom-up rectangles for one day's bar, one per project.
  def card_bar(day, scale, merged:)
    segments = merged && day.total.positive? ? [ WeekCards::ComposeService::Segment.new(project: nil, n: day.total, pattern: "solid") ] : day.segments
    bottom = 360
    segments.map do |segment|
      height = [ (segment.n * scale).round, 4 ].max
      bottom -= height
      top = bottom
      bottom -= 2
      { segment: segment, y: top, height: height }
    end
  end

  def card_fill(pattern)
    { "solid" => CARD[:line], "hatch" => "url(#wc-hatch)", "dots" => "url(#wc-dots)", "cross" => "url(#wc-cross)" }
      .fetch(pattern, "rgba(143, 211, 255, 0.10)")
  end

  # Breaks a headline into lines that fit a column, by character count: the
  # card's condensed face is narrow and even enough for that to hold.
  def card_lines(text, chars:, max_lines:)
    lines = text.to_s.split.each_with_object([ +"" ]) do |word, result|
      word = word.truncate(chars, omission: "…")
      if result.last.empty? then result.last << word
      elsif result.last.length + word.length < chars then result.last << " " << word
      else result << word.dup
      end
    end
    return lines if lines.size <= max_lines

    lines.first(max_lines).tap { |kept| kept[-1] = "#{kept[-1].truncate(chars - 1, omission: '')}…" }
  end

  # Legend items laid out leftward from the card's right edge.
  def card_legend(projects)
    right = CARD_RIGHT
    projects.select(&:shown).first(5).reverse.map do |project|
      width = 22 + 8 + (project.name.length * 8.4) + 8 + (project.n.to_s.length * 8.4)
      right -= width
      item = { project: project, x: right.round }
      right -= 22
      item
    end.reverse
  end
end
