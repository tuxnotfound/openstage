module CardLayout
  # The progress card, 1200x630, in the page's look: who and the window, the
  # commits with each project's share, the page's chart with its numbered
  # discs, and beside it the same numbers in the builder's words. Set in the
  # card's Funnel faces, measured by CardText, so the preview and the PNG are
  # one picture. What does not fit beside the chart goes, lowest ranked
  # first, and the editor offers it back with Swap in.
  class Progress
    WIDTH = 1200
    HEIGHT = 630
    LEFT = 56
    RIGHT = 1144
    PLOT = { left: 96, right: 688, top: 214, bottom: 532 }.freeze
    # bottom: where the last note must end; the line under it says what else
    # the window holds.
    NOTES = { left: 740, top: 214, bottom: 562, more: 592 }.freeze
    NOTE_TEXT = 776
    TITLE = 17
    LEAD = 22
    FAMILIES = [ "Funnel Card Sans", "Funnel Card Display" ].freeze
    PALETTES = {
      "light" => { bg: "#FFFFFF", ink: "#0E0F12", ink2: "#43464D", muted: "#666A73", line: "#E2E4E8" },
      "dark" => { bg: "#0E0F12", ink: "#F3F4F6", ink2: "#C5C8CE", muted: "#9499A2", line: "#2A2E35" }
    }.freeze

    Polyline = Data.define(:points, :color)
    Disc = Data.define(:cx, :cy, :r, :fill)
    Segment = Data.define(:x, :width, :color)
    # lines: the title as set, one or two lines; top: where the note starts.
    Note = Data.define(:item, :lines, :meta, :top)

    attr_reader :section, :user, :theme, :palette, :canvas, :notes, :chart

    def self.faces
      CardText::FACES.select { |_name, face| face[:families].intersect?(FAMILIES) }
    end

    def self.fonts
      CardText::FONTS.select { |font| FAMILIES.include?(font[:family]) }
    end

    def initialize(section, user:, theme:)
      @section = section
      @user = user
      @theme = PALETTES.key?(theme) ? theme : "light"
      @palette = PALETTES.fetch(@theme)
      @canvas = Canvas.new([])
      @notes = fit_notes
      @chart = ProgressChart::Trend.new(section, items: notes.map(&:item))
      Words.new(self).draw
    end

    def avatar_url
      user.avatar_url.presence
    end

    # The picks the card had no room for, with those the pick left out.
    def left_out
      (section.pick.kept - notes.map(&:item) + section.pick.left).sort_by { |item| [ item.date, item.id ] }
    end

    def segments
      counts = section.tally.projects.all.filter_map { |project| [ project, section.tally.totals.counts[project.repo].to_i ] }
                      .select { |_project, n| n.positive? }
      total = counts.sum(&:last).to_f
      room = RIGHT - LEFT - (4 * [ counts.size - 1, 0 ].max)
      x = LEFT
      counts.map do |project, n|
        width = [ room * n / total, 6 ].max
        Segment.new(x: x, width: width, color: color(project.rank)).tap { x += width + 4 }
      end
    end

    def polylines
      chart.lines.reverse.map do |line|
        points = line.values.each_with_index.map { |value, i| "#{num(plot_x(i))},#{num(plot_y(chart.top(value)))}" }.join(" ")
        Polyline.new(points: points, color: color(line.rank))
      end
    end

    def gridlines
      chart.ticks.map { |tick| plot_y(tick.top) }
    end

    def discs
      plot_width = PLOT[:right] - PLOT[:left]
      chart.discs.map do |disc|
        Disc.new(cx: PLOT[:left] + (disc.left / 100.0 * plot_width), cy: plot_y(disc.top), r: 15, fill: disc_color(disc.rank))
      end
    end

    # The disc that numbers a note in the column.
    def note_disc(note)
      Disc.new(cx: NOTES[:left] + 12, cy: note.top + 9, r: 12, fill: disc_color(project_rank(note.item)))
    end

    def plot_x(index)
      PLOT[:left] + (chart.x(index) / ProgressChart::Trend::WIDTH * (PLOT[:right] - PLOT[:left]))
    end

    def plot_y(percent)
      PLOT[:top] + (percent / 100.0 * (PLOT[:bottom] - PLOT[:top]))
    end

    def color(rank)
      ProgressChart::Palette.project_color(rank, theme == "dark" ? :dark : :page)
    end

    def disc_color(rank)
      rank ? color(rank) : palette[:ink]
    end

    def project_rank(item)
      item.repo_name && section.tally.projects.find(item.repo_name)&.rank
    end

    private

    # The most picks that fit beside the chart, set in date order. Pins stay
    # longest, then the swaps from the latest back, then the rest by rank, so
    # the latest swap always lands.
    def fit_notes
      pick = section.pick
      pins = pick.ranked.select(&:pinned?)
      kept = pins + (pick.swapped.reverse - pins) + (pick.ranked - pins - pick.swapped)
      kept.size.downto(1) do |count|
        notes = set_notes(kept.first(count).sort_by { |item| [ item.date, item.id ] })
        return notes if notes.last.top + height(notes.last) <= NOTES[:bottom]
      end
      []
    end

    def set_notes(items)
      top = NOTES[:top] + 30
      items.map do |item|
        Note.new(item: item, lines: Words.wrap(item.title.to_s.squish, RIGHT - NOTE_TEXT), meta: meta(item), top: top)
          .tap { |note| top += height(note) }
      end
    end

    def height(note)
      (note.lines.size * LEAD) + 20 + 14
    end

    def meta(item)
      project = item.repo_name && section.tally.projects.find(item.repo_name)
      [ item.date.strftime("%b %-d"), project&.name ].compact.join(" · ")
    end

    def num(value)
      Shapes.num(value)
    end
  end
end
