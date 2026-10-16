module CardLayout
  # The Journey card, 1200x630, made from the progress section's Lines view:
  # the period's commits added up as one ink line with the builder's words on
  # flags along it, each project's line beneath, and the period's numbers at
  # the top right, and the projects' legend at the bottom. A port of
  # doc/progress/mocks/CardJourney.dc.html, with circles where it has
  # diamonds, the project lines and their legend added (decided 2026-10-16).
  class Journey
    INTER_BASE = ProgressHeader::INTER_BASE
    PALETTES = Footnotes::PALETTES.to_h do |theme, colors|
      [ theme, colors.merge(pole: theme == "dark" ? "#4A5258" : "#BDBBB1") ]
    end.freeze
    UNDER = { rules: { stroke: :rule }, rules_strong: { stroke: :rule_strong }, poles: { stroke: :pole } }.freeze
    OVER = { halos: { fill: :bg }, ship: { fill: :ink }, ring_fill: { fill: :bg }, rings: { stroke: :ink, width: 2.6 },
             end_dot: { fill: :ink }, chip: { stroke: :rule_strong } }.freeze
    STAT_X = [ 672, 790, 908, 1026 ].freeze
    # Under the month labels, which sit on 578.
    LEGEND_TOP = 592

    attr_reader :section, :user, :theme, :palette, :canvas, :geometry, :flags, :strokes

    def self.faces
      Footnotes.faces
    end

    def self.fonts
      Footnotes.fonts
    end

    def initialize(section, user:, theme:)
      @section = section
      @user = user
      @theme = PALETTES.key?(theme) ? theme : "light"
      @palette = PALETTES.fetch(@theme)
      @canvas = Canvas.new(UNDER.keys + OVER.keys)
      @strokes = []
      @geometry = Geometry.new(section)
      @flags = Flags.new(@geometry, section).all
      draw
    end

    def avatar
      { url: user.avatar_url, cx: 88, cy: 80 } if user.avatar_url.present?
    end

    # The entries on flags, in date order: what the post lists.
    def items
      flags.map(&:item).sort_by { |item| [ item.date, item.id ] }
    end

    # The period's entries without a flag: the card had no room for their words.
    def left_out
      (section.tally.items - items).sort_by { |item| [ item.date, item.id ] }
    end

    def stroke(path, color, width)
      strokes << [ path, color, width ]
    end

    # A shape in a project's color: the legend's swatches.
    def fill(path, color)
      fills << [ path, color ]
    end

    def fills
      @fills ||= []
    end

    # The area under the ink line: ink, or the project's color under a filter.
    def wash_paint
      project = section.project
      return [ palette[:ink], 0.1, 0.02 ] unless project

      [ ProgressChart::Palette.project_color(project.rank, theme.to_sym), 0.22, 0.04 ]
    end

    private

    def draw
      ProgressHeader.new(self, dateline: section.labels.subtitle, dot: 12).draw
      canvas.draw(:rules, Shapes.rule(ProgressHeader::L, ProgressHeader::R, 136))
      stats
      Plot.new(self).draw
      ProgressLegend.new(self, top: LEGEND_TOP, width: 1080, swatch: :line).draw
    end

    # Shipped, published, commits and active days, each with its change; the
    # glyphs are the circles' key.
    def stats
      now = section.tally.totals
      before = section.tally.previous_totals
      [ [ "SHIPPED", now.shipped, before&.shipped, :filled ], [ "PUBLISHED", now.published, before&.published, :ring ],
        [ "COMMITS", now.commits, before&.commits, nil ],
        [ "ACTIVE DAYS", now.active_days, before&.active_days, nil ] ].each_with_index do |(label, value, previous, glyph), i|
        stat(STAT_X[i], label, value, previous, glyph)
      end
    end

    def stat(x, label, value, previous, glyph)
      ends = canvas.put(value.to_s, :inter_semibold, 30, x, 214, palette[:ink], spacing: -0.02)
      if previous
        change = value - previous
        text = if change.positive? then "+#{change}" elsif change.negative? then "−#{change.abs}" else "±0" end
        canvas.put(text, :dm_mono_medium, 12, ends + 8, 214, change.positive? ? palette[:accent] : palette[:faint])
      end
      text_x = glyph ? x + 15 : x
      key(x, 236 - (0.34 * 11), glyph) if glyph
      canvas.put(label, :dm_mono_medium, 11, text_x, 236, palette[:muted], spacing: 0.1)
    end

    def key(x, cy, glyph)
      if glyph == :filled
        canvas.draw(:ship, Shapes.rounded(x, cy - 5, 10, 10, 5))
      else
        canvas.draw(:rings, Shapes.rounded(x + 1.1, cy - 3.9, 7.8, 7.8, 3.9))
      end
    end
  end
end
