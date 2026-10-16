module CardLayout
  # The progress card, 1200x630, made from the section's Bars or Lines view.
  # Left: the period's chart with numbered discs on it. Right: the same
  # numbers start the notes, in the builder's words. A port of
  # doc/progress/mocks/CardFootnotes.dc.html, whose renderVals is the spec;
  # the Lines kind takes the page's lines in place of the bars (decided
  # 2026-10-16, replacing the Journey card's flags).
  class Footnotes
    L = 60
    R = 1140
    NOTES_X = 680
    TEXT_X = 716
    INTER_BASE = ProgressHeader::INTER_BASE
    FAMILIES = [ "Inter", "DM Mono" ].freeze
    PALETTES = {
      "light" => { bg: "#F8F7F3", ink: "#14171A", muted: "#62665F", faint: "#8A8E86", rule: "#E4E3DC",
                   rule_strong: "#CDCBC1", accent: "#00875A", ring: "#D9D7CE" },
      "dark" => { bg: "#0E1012", ink: "#ECEEEF", muted: "#8E959A", faint: "#6B7378", rule: "#22272B",
                  rule_strong: "#394046", accent: "#00BA7C", ring: "#2A3035" }
    }.freeze
    # Drawn under the bars, then over them.
    UNDER = { rules: { stroke: :rule }, rules_strong: { stroke: :rule_strong } }.freeze
    OVER = { end_fill: { fill: :bg }, end_ring: { stroke: :faint, width: 1.5 }, halos: { fill: :bg }, disc_ship: { fill: :ink }, disc_post: { fill: :bg },
             disc_ring: { stroke: :ink, width: 1.75 }, chip: { stroke: :rule_strong } }.freeze
    STAR = "M11.05 2.93c.3-.92 1.6-.92 1.9 0l1.52 4.67a1 1 0 00.95.69h4.91c.97 0 1.37 1.24.59 1.81l-3.98 2.89a1 1 0 00-.36 " \
           "1.12l1.52 4.67c.3.92-.76 1.69-1.54 1.12l-3.98-2.89a1 1 0 00-1.17 0l-3.98 2.89c-.78.57-1.84-.2-1.54-1.12l1.52-4.67a1 " \
           "1 0 00-.36-1.12L2.07 10.1c-.78-.57-.38-1.81.59-1.81h4.91a1 1 0 00.95-.69l1.53-4.67z".freeze

    attr_reader :section, :user, :theme, :kind, :palette, :canvas, :fills, :strokes, :fit
    # [path, color]: the area under the one project's line.
    attr_accessor :wash

    # The type it draws with, for card_face_css, and the files the PNG embeds.
    def self.faces
      CardText::FACES.select { |_name, face| face[:families].intersect?(FAMILIES) }
    end

    def self.fonts
      CardText::FONTS.select { |font| FAMILIES.include?(font[:family]) }
    end

    # kind: :bars or :lines.
    def initialize(section, user:, theme:, kind: :bars)
      @section = section
      @user = user
      @theme = PALETTES.key?(theme) ? theme : "light"
      @kind = kind == :lines ? :lines : :bars
      @palette = PALETTES.fetch(@theme)
      @canvas = Canvas.new(UNDER.keys + OVER.keys)
      @fills = []
      @strokes = []
      @fit = Notes.fit(section.pick.kept, ranked: section.pick.ranked, swapped_ids: section.pick.swapped.map(&:id),
                       project_names: section.tally.projects.all.map(&:name))
      draw
    end

    def avatar
      { url: user.avatar_url, cx: 88, cy: 80 } if user.avatar_url.present?
    end

    # The picked entries the card had no room for, with the ones the pick left out.
    def left_out
      (section.pick.kept - fit.notes.map(&:item) + section.pick.left).sort_by { |item| [ item.date, item.id ] }
    end

    def fill(path, color)
      fills << [ path, color ]
    end

    def stroke(path, color, width)
      strokes << [ path, color, width ]
    end

    # A numbered disc, or a pill: filled when it holds a shipped entry, a ring
    # otherwise, with a halo of the ground around it.
    def disc(x, y, width, label, shipped)
      canvas.draw(:halos, Shapes.rounded(x - 2, y - 2, width + 4, 24, 12))
      if shipped
        canvas.draw(:disc_ship, Shapes.rounded(x, y, width, 20, 10))
      else
        canvas.draw(:disc_post, Shapes.rounded(x, y, width, 20, 10))
        canvas.draw(:disc_ring, Shapes.rounded(x + 0.875, y + 0.875, width - 1.75, 18.25, 9.125))
      end
      text_width = Type.width(label, :inter_semibold, 12)
      canvas.put(label, :inter_semibold, 12, x + ((width - text_width) / 2), y + 10 + (INTER_BASE * 12),
                 shipped ? palette[:bg] : palette[:ink])
    end

    private

    def draw
      ProgressHeader.new(self, dateline: dateline).draw
      canvas.draw(:rules, Shapes.rule(L, R, 136))
      canvas.draw(:rules, "M650.5,166V580")
      Chart.new(self, fit.notes.map(&:item)).draw
      Column.new(self).draw
    end

    # "Jan 1 – Oct 15, so far · 380 commits on 64 days"
    def dateline
      totals = section.tally.totals
      "#{section.labels.subtitle.sub(' · so far', ', so far')} · #{totals.commits} #{'commit'.pluralize(totals.commits)} " \
        "on #{totals.active_days} #{'day'.pluralize(totals.active_days)}"
    end
  end
end
