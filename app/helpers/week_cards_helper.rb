# Layout for the week card's SVG, 1200x630, drawn on the server so the
# editor's preview and the downloaded PNG are the same picture. SVG cannot flow
# text, so text is measured with CardText and placed here.
module WeekCardsHelper
  CARD_LEFT = 26
  CARD_RIGHT = 1174
  CARD_THEMES = {
    "light" => { ground: "#F3F5F8", panel: "#FFFFFF", border: "#DCE1E7", axis: "#C3CBD4", text: "#0F1419",
                 muted: "#5B6670", quiet: "#A3ACB5", faint: "#E3E7EC", up: "#00875A", down: "#D3214F" },
    "dark" => { ground: "#0B0D10", panel: "#15181D", border: "#2A2F37", axis: "#3A4049", text: "#E7E9EA",
                muted: "#8B929B", quiet: "#4A5058", faint: "#262B32", up: "#00BA7C", down: "#F4212E" }
  }.freeze
  PROJECT_COLORS = %w[#1D9BF0 #00BA7C #FFB020 #8B5CF6 #EC4899 #14B8A6].freeze
  OTHER_COLOR = "#7A8691".freeze
  CELL_WEIGHTS = { goal: 1.15, audience: 1, hours: 1.25, code: 1.2, repos: 1.2 }.freeze

  def card_theme(card)
    CARD_THEMES.fetch(card.week_card.theme, CARD_THEMES["light"])
  end

  def card_face(mono: false)
    (mono ? "font-family=\"'DM Mono', monospace\"" : "font-family=\"'DM Sans', sans-serif\"").html_safe
  end

  # Where the strip and the timeline sit, and the timeline's line, halfway
  # down. Without extras cells the timeline takes their room; without a strip
  # it moves up.
  def card_bands(card, cells)
    strip = card.week_card.shows?("totals") || card.week_card.shows?("projects")
    top = strip ? 130 : 82
    bottom = cells.any? ? 462 : 576
    { strip: strip, top: top, bottom: bottom, line: (top + bottom) / 2 }
  end

  def card_project_color(slot)
    slot ? PROJECT_COLORS.fetch(slot, OTHER_COLOR) : OTHER_COLOR
  end

  # Cuts text to a width, ending in an ellipsis when cut.
  def card_fit(text, width, **font)
    text = text.to_s
    return text if CardText.width(text, **font) <= width

    text = text[0...-1] while text.length > 1 && CardText.width("#{text.rstrip}…", **font) > width
    "#{text.rstrip}…"
  end

  # Breaks text into lines of a width, at most max_lines; the last line ends
  # in an ellipsis when there was more.
  def card_wrap(text, width, max_lines:, **font)
    lines = text.to_s.split.each_with_object([]) do |word, result|
      joined = [ result.last, word ].compact.join(" ")
      if result.any? && CardText.width(joined, **font) <= width then result[-1] = joined
      else result << card_fit(word, width, **font)
      end
    end
    return lines if lines.size <= max_lines

    lines.first(max_lines).tap { |kept| kept[-1] = card_fit("#{kept[-1]} #{lines[max_lines]}", width, **font) }
  end

  # The strip's numbers, left to right, each as { x:, value:, label:, delta: }
  # with a divider before all but the first.
  def card_facts(card)
    x = CARD_LEFT + 16.0
    card_fact_values(card).map do |value, label, delta|
      width = CardText.width(value, size: 14, weight: 700) + 5 + CardText.width(label, size: 14)
      width += 5 + CardText.width(delta.first, size: 12, weight: 500) if delta
      fact = { x: x.round, value: value, label: label, delta: delta, right: (x + width).round }
      x += width + 28
      fact
    end
  end

  def card_fact_values(card)
    now = card.totals
    before = card.week_card.shows?("compare") ? card.previous&.totals : nil
    facts = []
    facts << [ now.shipped.to_s, "shipped", card_delta(now.shipped, before&.shipped) ] if now.shipped.positive?
    facts << [ now.commits.to_s, "commit".pluralize(now.commits), card_delta(now.commits, before&.commits, percent: true) ] if now.commits.positive?
    facts << [ "#{now.active_days}/7", "days building", card_delta(now.active_days, before&.active_days) ]
    facts << [ now.published.to_s, "published", card_delta(now.published, before&.published) ] if now.published.positive?
    facts
  end

  # ["↑ 131%", :up] or ["↓ 2", :down]; nil with nothing to compare or no change.
  def card_delta(now, before, percent: false)
    return if before.nil? || (percent && before.zero?)

    change = percent ? ((now - before) * 100.0 / before).round : now - before
    return if change.zero?

    [ "#{change.positive? ? '↑' : '↓'} #{change.abs}#{'%' if percent}", change.positive? ? :up : :down ]
  end

  # Legend items, busiest project first, as many as fit between the numbers
  # and the strip's right edge, which the last one ends on.
  def card_legend(projects, after:)
    room = CARD_RIGHT - 16.0 - after - 20
    items = projects.select(&:shown).each_with_object([]) do |project, kept|
      name = card_fit(project.name, 150, size: 12, weight: 500)
      width = 22 + CardText.width(name, size: 12, weight: 500) + 4 + CardText.width(project.n.to_s, size: 12)
      break kept if (room -= width + 14) < -14

      kept << { project: project, name: name, width: width }
    end
    x = CARD_RIGHT - 16.0 - items.sum { |item| item[:width] + 14 } + 14
    items.map { |item| item.merge(x: x.round).tap { x += item[:width] + 14 } }
  end

  # The extras cells the card shows, left to right, sized by weight.
  def card_cells(card)
    wc = card.week_card
    data = card.extras.to_h.merge(goal: wc.next_goal)
    kinds = CELL_WEIGHTS.keys.select { |kind| wc.shows?(kind.to_s) && data[kind] }
    total = kinds.sum { |kind| CELL_WEIGHTS[kind] }
    left = CARD_LEFT.to_f
    kinds.map do |kind|
      width = (CARD_RIGHT - CARD_LEFT) * CELL_WEIGHTS[kind] / total
      cell = { kind: kind, x: left.round, width: width.round, data: data[kind] }
      left += width
      cell
    end
  end
end
