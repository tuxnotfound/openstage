module CardLayout
  # Measuring and fitting one line of text in a CardText face. A width here is
  # the visible width: letter-spacing (in ems) follows every character, the
  # last one included, so the last one's is left out.
  module Type
    # Cap and figure heights in ems, measured in Chrome, by family.
    HEIGHTS = { "Inter" => { cap: 0.7275, fig: 0.737 }, "DM Mono" => { cap: 0.70, fig: 0.712 },
                "Funnel Card Sans" => { cap: 0.675, fig: 0.685 }, "Funnel Card Display" => { cap: 0.675, fig: 0.685 } }.freeze

    module_function

    def width(text, face, size, spacing = 0)
      CardText.width(text, size: size, face: face, spacing: spacing * size) - (spacing * size)
    end

    def cap(face, size)
      HEIGHTS.fetch(CardText::FACES.fetch(face)[:families].last)[:cap] * size
    end

    def fig(face, size)
      HEIGHTS.fetch(CardText::FACES.fetch(face)[:families].last)[:fig] * size
    end

    # A size fitted to a room, rounded down to the tenth so it still fits.
    def fit(size)
      ((size * 10) + 1e-6).floor / 10.0
    end

    # Cut inside a word, for text the builder did not write.
    def cut(text, face, size, spacing, room)
      return text if width(text, face, size, spacing) <= room

      chars = text.chars
      chars.pop while chars.size > 1 && width("#{chars.join}…", face, size, spacing) > room
      "#{chars.join.rstrip}…"
    end

    # Cut at the last word that fits, or inside a word when none does.
    def cut_words(text, face, size, spacing, room)
      return text if width(text, face, size, spacing) <= room

      words = text.split(" ")
      while words.size > 1
        words.pop
        cut = "#{words.join(' ').sub(/[\s,;:·–-]+\z/, '')}…"
        return cut if width(cut, face, size, spacing) <= room
      end
      cut(text, face, size, spacing, room)
    end

    # A long project name is cut at its last "-", "_" or space inside the limit.
    def cut_name(name, limit)
      return name if name.length <= limit

      head = name[0, limit - 1]
      at = [ head.rindex("-"), head.rindex("_"), head.rindex(" ") ].compact.max || -1
      "#{(at >= 6 ? head[0, at] : head).sub(/[-_ ]+\z/, '')}…"
    end

    # "1,284"
    def number(value)
      value.to_i.to_fs(:delimited)
    end
  end
end
