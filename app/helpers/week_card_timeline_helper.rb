# The week card's timeline: a line through the middle of the panel and one
# invisible column per day. A day's bar grows from the line, up and down in
# turn, and its words sit on the other side; nothing leaves its column.
module WeekCardTimelineHelper
  TIMELINE_LEFT = 40
  TIMELINE_WIDTH = 1120
  BAR_WIDTH = 26
  # Thin weeks keep honest bars: one commit never stands taller than this.
  BAR_PER_COMMIT = 16
  # Room for the label at a bar's far end, and a margin to the panel's edge.
  BAR_CAP = 36
  # Space between the line and the words, and between words and their column.
  WORDS_GAP = 14
  WORDS_PADDING = 6

  # One column per day, left to right; the first day's bar goes up.
  def card_columns(days)
    width = TIMELINE_WIDTH.to_f / days.size
    days.each_with_index.map do |day, i|
      { day: day, cx: (TIMELINE_LEFT + (width * (i + 0.5))).round, width: width, up: i.even? }
    end
  end

  def card_bar_scale(days, height)
    most = days.map(&:total).max.to_i
    most.zero? ? 0 : [ height.to_f / most, BAR_PER_COMMIT ].min
  end

  # A day's bar as blocks from the line outward, busiest project nearest the
  # line, or one block for the day when the card hides projects. The last
  # block is the bar's far end.
  def card_bar(day, scale, line:, up:, merged:)
    segments = day.segments
    segments = [ WeekCards::TallyService::Segment.new(project: nil, n: day.total, slot: 0) ] if merged && day.total.positive?
    edge = up ? line - 1 : line + 1
    segments.map do |segment|
      height = [ (segment.n * scale).round, 3 ].max
      y = up ? edge - height : edge
      edge = up ? y - 2 : y + height + 2
      { segment: segment, y: y, height: height }
    end
  end

  # A block with its two corners away from the line rounded.
  def card_block_path(x, y, width, height, up:)
    r = [ 6, height / 2.0 ].min
    if up
      "M#{x} #{y + height}V#{y + r}Q#{x} #{y} #{x + r} #{y}H#{x + width - r}Q#{x + width} #{y} #{x + width} #{y + r}V#{y + height}Z"
    else
      far = y + height
      "M#{x} #{y}V#{far - r}Q#{x} #{far} #{x + r} #{far}H#{x + width - r}Q#{x + width} #{far} #{x + width} #{far - r}V#{y}Z"
    end
  end

  # A project's colour for text, or nil without a project. Amber is too pale
  # to read on white, so the light card takes a deeper shade.
  def card_project_ink(slot, theme)
    return if slot.nil?

    color = card_project_color(slot)
    color == "#FFB020" && theme == "light" ? "#B7791F" : color
  end

  # The type shrinks until the longest word fits, so a domain like
  # playwheelsoff.com is never cut.
  def card_headline_size(text, width, base:, weight:)
    longest = text.to_s.split.max_by { |word| CardText.width(word, size: base, weight: weight) }.to_s
    size = base
    size -= 1 while size > 11 && CardText.width(longest, size: size, weight: weight) > width
    size
  end

  # What a day says beside its bar, top to bottom: the kind, the headline, and
  # the commits per project. Rows carry baselines from the top of the block,
  # chips their offsets from the column's centre; height is the whole block's.
  def card_day_words(day, headline, width:, merged:)
    base, weight = headline.kind == "shipped" ? [ 17, 700 ] : [ 15, 600 ]
    size = card_headline_size(headline.text, width, base: base, weight: weight)
    rows = [ { kind: headline.kind.upcase, y: 9 } ]
    cursor = 14.0
    card_wrap(headline.text, width, max_lines: 3, size: size, weight: weight).each do |line|
      cursor += size * 1.2
      rows << { line: line, size: size, weight: weight, y: (cursor - (size * 0.25)).round(1) }
    end
    cursor += 4
    (merged ? [] : card_chip_rows(day.segments, width)).each do |chips|
      cursor += 15
      rows << { chips: chips, y: (cursor - 3.5).round(1) }
    end
    { rows: rows, height: cursor }
  end

  # "wheels-off 4" chips, as many to a row as fit the column, each row centred.
  def card_chip_rows(segments, width)
    chips = segments.map do |segment|
      text = card_fit("#{segment.project} #{segment.n}", width - 12, size: 12)
      { text: text, slot: segment.slot, width: 12 + CardText.width(text, size: 12) }
    end
    rows = chips.each_with_object([]) do |chip, result|
      if result.any? && result.last.sum { |c| c[:width] + 10 } + chip[:width] <= width then result.last << chip
      else result << [ chip ]
      end
    end
    rows.first(3).map do |row|
      x = -(row.sum { |chip| chip[:width] } + (10 * (row.size - 1))) / 2.0
      row.map { |chip| chip.merge(x: x.round(1)).tap { x += chip[:width] + 10 } }
    end
  end
end
