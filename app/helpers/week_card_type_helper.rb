# Type for the week card templates that set Newsreader and Inter (the faces in
# CardText::FACES): the CSS that pins each face, widths, cuts, and balanced
# line breaking. Every line break is decided here, since SVG cannot flow text.
module WeekCardTypeHelper
  # Words that belong with the next one, so a line should not end on them.
  SHORT_WORDS = %w[a an the of to in on at by for and or i & with my via from into our your its].to_set.freeze
  # Words that open a phrase, so a line may start on them.
  JOIN_WORDS = %w[via with for to in from and or but of on at by into as than that while when because before after
                  without through across over about].to_set.freeze
  JOIN_BONUS = 0.02
  SHORT_COST = 0.09
  TIE_COST = 0.01
  CJK = /[⺀-鿿가-힯豈-﫿＀-￯]/
  # Closing marks and small kana never start a line (kinsoku).
  NO_START = /[、。，．・：；？！ー）」』】〕〉》ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ]/

  # One class per face, pinning the instance CardText measured, so the browser
  # draws those exact widths at any size.
  def card_face_css
    CardText::FACES.map do |name, face|
      ".#{card_face_class(name)}{font-family:'#{face[:family]}';font-style:#{face[:style]};font-weight:#{face[:weight]};" \
        "font-variation-settings:'opsz' #{face[:opsz]},'wght' #{face[:weight]};font-feature-settings:#{face[:features]}}"
    end.join.html_safe
  end

  def card_face_class(face)
    "cf-#{face.to_s.dasherize}"
  end

  # Visible width: letter-spacing (in ems) follows every character, so the
  # last one's is left out.
  def card_text_width(text, face, size, spacing = 0)
    CardText.width(text, size: size, face: face, spacing: spacing * size) - (spacing * size)
  end

  def card_cut_to_width(text, face, size, spacing, room)
    return text if card_text_width(text, face, size, spacing) <= room

    chars = text.chars
    chars.pop while chars.size > 1 && card_text_width("#{chars.join}…", face, size, spacing) > room
    "#{chars.join.rstrip}…"
  end

  # Cut at the last word that fits, or inside a word when none does.
  def card_cut_words(text, face, size, spacing, room)
    return text if card_text_width(text, face, size, spacing) <= room

    words = text.split(" ")
    while words.size > 1
      words.pop
      cut = "#{words.join(' ').sub(/[\s,;:·–-]+\z/, '')}…"
      return cut if card_text_width(cut, face, size, spacing) <= room
    end
    card_cut_to_width(text, face, size, spacing, room)
  end

  # A long project name is cut at its last "-", "_" or space inside the limit.
  def card_cut_name(name, limit)
    return name if name.length <= limit

    head = name[0, limit - 1]
    at = [ head.rindex("-"), head.rindex("_"), head.rindex(" ") ].compact.max || -1
    "#{(at >= 6 ? head[0, at] : head).sub(/[-_ ]+\z/, '')}…"
  end

  # The fewest lines that fit the room, then the split that costs least (see
  # card_split_cost). Lines break at spaces, then also after hyphens, and
  # between CJK characters, which have no spaces. nil when nothing fits.
  def card_balance(text, face, size, spacing, room, max_lines, strict: false)
    [ false, true ].each do |hyphens|
      tokens = card_tokens(text, hyphens)
      width = card_line_width(tokens, face, size, spacing)
      (1..[ max_lines, tokens.size ].min).each do |count|
        ends = card_best_split(tokens, width, count, room, strict)
        return card_join_lines(tokens, ends) if ends
      end
    end
    nil
  end

  def card_tokens(text, hyphens)
    text.split(" ").each_with_index.flat_map do |word, w|
      parts = hyphens ? word.split(/(?<=-)(?=.)/) : [ word ]
      parts.flat_map { |part| CJK.match?(part) ? card_cjk_parts(part) : [ part ] }
           .each_with_index.map { |part, p| { text: part, space: p.zero? && w.positive? } }
    end
  end

  def card_cjk_parts(text)
    text.each_char.with_object([]) do |char, parts|
      if parts.any? && NO_START.match?(char) then parts[-1] += char
      elsif parts.empty? || CJK.match?(char) || CJK.match?(parts.last[-1]) then parts << char
      else parts[-1] += char
      end
    end
  end

  # The width of tokens i...j set as one line, from running sums.
  def card_line_width(tokens, face, size, spacing)
    widths = tokens.map { |token| CardText.width(token[:text], size: size, face: face, spacing: spacing * size) }
    space = CardText.width(" ", size: size, face: face, spacing: spacing * size)
    sums = widths.each_with_object([ 0.0 ]) { |width, acc| acc << (acc.last + width) }
    spaces = tokens.each_with_object([ 0 ]) { |token, acc| acc << (acc.last + (token[:space] ? 1 : 0)) }
    ->(i, j) { sums[j] - sums[i] + ((spaces[j] - spaces[i + 1]) * space) - (spacing * size) }
  end

  def card_best_split(tokens, width, count, room, strict)
    best, best_cost = nil, Float::INFINITY
    (1...tokens.size).to_a.combination(count - 1).each do |breaks|
      ends = breaks + [ tokens.size ]
      cost = card_split_cost(tokens, ends, ends.each_with_index.map { |j, k| width.call(k.zero? ? 0 : ends[k - 1], j) }, room, strict)
      best, best_cost = ends, cost if cost && cost < best_cost
    end
    best
  end

  # Even lines: the sum of the squared widths. A line that ends on a short word
  # costs a penalty, and in display type (strict) is not allowed at all. A line
  # that opens on a joining word earns a bonus, so a phrase stays whole ("Read-
  # only private repos / via a GitHub App"), and near-ties settle toward a
  # longer first line.
  def card_split_cost(tokens, ends, widths, room, strict)
    return if widths.any? { |width| width > room }

    short = ends[0...-1].count { |j| tokens[j][:space] && SHORT_WORDS.include?(card_word(tokens[j - 1])) }
    return if strict && short.positive?

    joins = ends[0...-1].count { |i| tokens[i][:space] && JOIN_WORDS.include?(card_word(tokens[i])) }
    ties = widths.each_cons(2).sum { |above, below| below > above ? TIE_COST * room * (below - above) : 0 }
    widths.sum { |width| width * width } + (((short * SHORT_COST) - (joins * JOIN_BONUS)) * room * room) + ties
  end

  def card_word(token)
    token[:text].downcase.gsub(/[^\p{L}&]/, "")
  end

  def card_join_lines(tokens, ends)
    ends.each_with_index.map do |j, k|
      tokens[(k.zero? ? 0 : ends[k - 1])...j].each_with_index.map { |token, n| (n.positive? && token[:space] ? " " : "") + token[:text] }.join
    end
  end
end
