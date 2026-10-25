# Drawing the cards a shared link shows (app/views/og_images): 1200 by 630, in
# the app's light colours and fonts, since a card cannot follow the reader's
# dark mode. librsvg measures no text for us, so text is fitted by an average
# letter's width.
module ShareCardHelper
  INK = "#0E0F12".freeze
  INK_2 = "#43464D".freeze
  INK_3 = "#666A73".freeze
  LINE = "#E2E4E8".freeze
  ACCENT = "#006B72".freeze
  ACCENT_SOFT = "#E0EDEE".freeze
  FILL = "#F3F4F6".freeze
  DISPLAY = "Funnel Display".freeze
  SANS = "Funnel Sans".freeze
  # An average letter's width as a share of the font size, a little wide so
  # text that fits by this measure fits on the card. Display is set bold.
  LETTER = { DISPLAY => 0.5, SANS => 0.48 }.freeze

  def share_card_text(text, x:, y:, size:, font: SANS, weight: 400, fill: INK, anchor: "start")
    tag.text(text, x: x, y: y, "font-family" => font, "font-weight" => weight, "font-size" => size, fill: fill, "text-anchor" => anchor)
  end

  # The largest of `sizes` at which `text` fits `width` on one line, with the
  # text, cut with … at the smallest size when it fits none.
  def share_card_fit(text, width:, sizes:, font: SANS)
    size = sizes.find { |s| text.length <= share_card_chars(width, s, font) } || sizes.last
    [ share_card_cut(text, share_card_chars(width, size, font)), size ]
  end

  # Whole words in at most `lines` lines of `width`, the last cut with … when
  # the text runs on.
  def share_card_lines(text, width:, size:, lines:, font: SANS)
    chars = share_card_chars(width, size, font)
    text.to_s.split.each_with_object([]) do |word, out|
      if out.any? && "#{out.last} #{word}".length <= chars
        out[-1] = "#{out.last} #{word}"
      elsif out.size < lines
        out << share_card_cut(word, chars)
      else
        out[-1] = "#{out.last[0, chars - 1].rstrip.sub(/[[:punct:]]+\z/, '')}…"
        break out
      end
    end
  end

  def share_card_cut(text, chars)
    text.length > chars ? "#{text[0, chars - 1].rstrip}…" : text
  end

  # Each part of the share bar as [x, width]: its share of `width` with a gap
  # between parts, never narrower than `min`; the widest part gives way.
  def share_card_segments(counts, x:, width:, gap:, min:)
    usable = width - gap * (counts.size - 1)
    widths = counts.map { |count| [ usable * count.to_f / counts.sum, min ].max }
    widths[widths.index(widths.max)] -= widths.sum - usable
    widths.each_with_object([]) do |w, parts|
      parts << [ (parts.empty? ? x : parts.last.sum + gap).round(1), w.round(1) ]
    end
  end

  # A line of the page's chart (ProgressChart::Trend) across a box.
  def share_card_trend(chart, line, left:, right:, top:, bottom:)
    line.values.each_with_index.map do |value, i|
      x = left + (chart.x(i) / ProgressChart::Trend::WIDTH * (right - left))
      y = top + (chart.top(value) / 100.0 * (bottom - top))
      "#{x.round(1)},#{y.round(1)}"
    end.join(" ")
  end

  # Image bytes as a data URI: librsvg draws no image from the network.
  def share_card_image(bytes)
    type = bytes.start_with?("\x89PNG".b) ? "png" : "jpeg"
    "data:image/#{type};base64,#{Base64.strict_encode64(bytes)}"
  end

  def share_card_initials(user)
    user.display_name.to_s.split.first(2).map { |word| word[0] }.join.upcase.presence || user.username[0].upcase
  end

  def share_card_color(rank)
    ProgressChart::Palette.project_color(rank)
  end

  private

  def share_card_chars(width, size, font)
    (width / (size * LETTER.fetch(font))).floor
  end
end
