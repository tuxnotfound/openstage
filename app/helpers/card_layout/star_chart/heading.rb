module CardLayout
  class StarChart
    # The top of the left column: name, handle and Pro on one line, the week
    # in the top-right corner, then the persona: its title, its tagline and
    # the evidence for it.
    class Heading
      TOP = 25
      TITLE_TOP = 61
      PRO_W = 33
      # Sizes for the handle, whether Pro shows, and the name's size, from the
      # roomiest. Past them, the handle and then the name are shortened.
      LADDER = [ [ 12, true, 19 ], [ 11.5, true, 19 ], [ 11, true, 19 ], [ 11, false, 19 ], [ 11, false, 17 ] ].freeze
      EVIDENCE_S = 15
      EVIDENCE_LS = 0.04

      # persona: the card's, or nil when the builder turned it off.
      # title: { text:, size:, baseline: }, for its starlight.
      attr_reader :persona, :title, :list_top

      def initialize(chart)
        @chart = chart
        @canvas = chart.canvas
        @palette = chart.palette
        @persona = chart.card.persona if chart.shows?("persona")
        identity
        week
        persona_lines
      end

      private

      def user
        @chart.card.user
      end

      def mono(text, size, spacing = 0)
        CardText.width(text, size: size, face: :dm_mono_regular, spacing: spacing * size)
      end

      def bold(text, size)
        CardText.width(text, size: size, face: :dm_sans_bold)
      end

      # When the line overflows: the handle steps down, then Pro goes, then
      # the name steps down to 17px, then the handle is shortened, then the
      # name. The footer link always carries the full handle.
      def identity
        name = (user.display_name.presence || user.username).to_s if @chart.shows?("name")
        handle = "@#{user.github_username}" if @chart.shows?("github") && user.github_username.present?
        size, pro, name_size = fit(name, handle)
        line(name, handle, size, pro, name_size)
      end

      def line(name, handle, size, pro, name_size)
        x = LEFT
        x = put_name(name, name_size) + 8 if name
        x = @canvas.put(@handle || handle, :dm_mono_regular, size, x, baseline(name_size || size), @palette[:muted]) + 8 if handle
        pro_chip(x, baseline(name_size || size)) if pro && name
      end

      def fit(name, handle)
        LADDER.each do |size, pro_room, name_size|
          pro = pro_room && user.pro? && name.present?
          width = (name ? bold(name, name_size) + 8 : 0) + (handle ? mono(handle, size) : 0) + (pro ? 8 + PRO_W : 0)
          return [ size, pro, name && name_size ] if width <= WIDTH
        end
        @name, @handle = shorten(name, handle)
        [ 11, false, name && 17 ]
      end

      def shorten(name, handle)
        if name
          room = [ 160, WIDTH - 8 - (handle ? mono("#{handle[0, 12]}…", 11) : 0) ].max
          name = StarChart.cut(name, room) { |text| bold(text, 17) }
        end
        handle &&= StarChart.cut(handle, WIDTH - 8 - (name ? bold(name, 17) : 0)) { |text| mono(text, 11) }
        [ name, handle ]
      end

      def put_name(name, size)
        @canvas.put(@name || name, :dm_sans_bold, size, LEFT, baseline(size), @palette[:title])
      end

      # The line's items share a baseline, set by its biggest type.
      def baseline(size)
        TOP + (0.99 * size)
      end

      # PRO in a gold outline, its box 1px above the shared baseline.
      def pro_chip(x, baseline)
        text_w = mono("PRO", 9.5, 0.12)
        top = baseline - StarChart.base_in(13, 9.5) - 2
        @canvas.draw(:chip, Shapes.outline(x, top, 1 + 5 + text_w + 4 + 1, 15, 3))
        @canvas.put("PRO", :dm_mono_regular, 9.5, x + 6, baseline - 1, @palette[:gold], spacing: 0.12)
      end

      # The week, right-aligned in the top-right corner on the name's
      # baseline, clear of the 00h label.
      def week
        full = "WEEK #{@chart.card.week_card.week_start.cweek} · #{@chart.card.dates.upcase}"
        compact = full.sub(/, \d{4} – /, " – ")
        options = [ [ full, 12, 0.08 ], [ full, 12, 0.04 ], [ full, 11.5, 0.04 ], [ full, 11.5, 0 ], [ compact, 11.5, 0.04 ], [ compact, 11, 0 ] ]
        text, size, spacing = options.find { |option| mono(*option) <= 1164 - 946 } || [ compact, 11, 0 ]
        @canvas.put_end(text, :dm_mono_regular, size, 1164, 44, @palette[:title], spacing: spacing)
      end

      # Without the persona, the week names itself.
      def persona_lines
        text = persona ? persona.title : @chart.card.label
        size = CardText.width(text, size: 48, face: :newsreader_title, spacing: -0.02 * 48) <= 520 ? 48 : 42
        baseline = TITLE_TOP + (size * 0.737).round
        @title = { text: text, size: size, baseline: baseline }
        @canvas.put(text, :newsreader_title, size, 46, baseline, @palette[:title], spacing: -0.02)
        @list_top = persona ? tagline_and_evidence(baseline + 12) : baseline + 24
      end

      # The second clause prints only when the whole line fits.
      def tagline_and_evidence(top)
        @canvas.put(persona.tagline, :dm_sans_medium, 16, LEFT, top + StarChart.base_in(21, 16), @palette[:text])
        evidence = [ persona.evidence, persona.extra ].compact.join(" · ")
        evidence = persona.evidence if mono(evidence, EVIDENCE_S, EVIDENCE_LS) > WIDTH
        @canvas.put(evidence, :dm_mono_regular, EVIDENCE_S, LEFT, top + 25 + StarChart.base_in(20, EVIDENCE_S), @palette[:gold],
                    spacing: EVIDENCE_LS)
        top + 25 + 20 + 12
      end
    end
  end
end
