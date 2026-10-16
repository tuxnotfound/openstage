module ProgressChart
  # The progress section's chart, laid out for the page: Bars or Lines. The
  # SVG is drawn in a 640 by 300 box that scales with its column; the HTML
  # laid over it (axis labels, discs and the hover columns) is placed in
  # percentages of that box, so it stays put at any width.
  class Page
    WIDTH = 640
    HEIGHT = 300
    FRAME = Bars::Frame.new(left: 34, right: 632, top: 34, bottom: 244)
    # The axis labels' middle: under the bars, or under the track of circles.
    AXIS_Y = { bars: 262, lines: 288 }.freeze
    # With every project's line drawn, most entries have no line to stand on,
    # so their circles stand on a track under the chart.
    TRACK_Y = 264
    SHAPE = Discs::Shape.new(size: 18, pill: 30, gap: 3, lift: 4)
    LEGEND_SIZE = 5

    Tick = Data.define(:value, :top)
    Label = Data.define(:text, :left, :tone)
    Track = Data.define(:columns, :width, :frame)

    attr_reader :section, :kind, :series, :discs

    delegate :columns, to: :tooltips

    def initialize(section, kind = "bars")
      @section = section
      @kind = kind.to_s == "lines" ? :lines : :bars
      geometry = lines? ? Lines : Bars
      @series = geometry.new(tally.buckets, repos: tally.projects.all.map(&:repo), colors: colors, frame: FRAME)
      @discs = place_discs
    end

    def lines?
      kind == :lines
    end

    def on_track?
      lines? && section.project.nil?
    end

    def ticks
      series.scale.ticks.map { |value| Tick.new(value: value, top: top(series.scale.y(value))) }
    end

    def grid_path
      series.scale.ticks.drop(1).map { |value| "M#{FRAME.left},#{num(series.scale.y(value))}H#{FRAME.right}" }.join
    end

    def base_path
      "M#{FRAME.left},#{FRAME.bottom}H#{FRAME.right}"
    end

    def track_path
      "M#{FRAME.left},#{TRACK_Y}H#{FRAME.right}" if on_track?
    end

    # Under a filter, the area under the project's line in its color.
    def wash
      [ series.wash(section.project.repo), Palette.project_color(section.project.rank) ] if lines? && section.project
    end

    def labels
      tally.period.buckets.filter_map do |bucket|
        text = section.labels.axis(bucket)
        Label.new(text: text, left: left(series.center(bucket.index)), tone: section.labels.axis_tone(bucket)) if text.present?
      end
    end

    def label_top
      top(AXIS_Y.fetch(kind))
    end

    # The hover wash's height: the plot, and the track below it when shown.
    def hover_height
      top((on_track? ? TRACK_Y + 12 : FRAME.bottom) - (FRAME.top - 10))
    end

    # The period's projects, busiest first; nil without a choice to make.
    def legend
      rows = tooltips.rows(tally.totals.counts).select(&:repo)
      rows if section.project.nil? && rows.size > 1
    end

    def aria_label
      unit = { day: "day", week: "week", month: "month" }.fetch(tally.period.unit)
      "#{lines? ? 'Commits added up per project' : "Commits per #{unit} by project"}, #{section.labels.title}"
    end

    def left(x)
      (100.0 * x / WIDTH).round(1)
    end

    def top(y)
      (100.0 * y / HEIGHT).round(1)
    end

    def disc_label(disc)
      disc.items.zip(disc.numbers).map do |item, n|
        "Note #{n}, #{item.shipped? ? 'shipped' : 'published'} #{item.date.strftime('%b %-d')}: #{item.title}"
      end.join(". ")
    end

    private

    def tally
      section.tally
    end

    def tooltips
      @tooltips ||= Tooltips.new(self)
    end

    def colors
      colors = tally.projects.all.to_h { |project| [ project.repo, Palette.project_color(project.rank) ] }
      colors.default = Palette.project_color(nil)
      colors
    end

    def place_discs
      kept = section.pick.kept
      return Markers.new(kept, period: tally.period, lines: series, repo: section.project.repo, shape: SHAPE).all if lines? && section.project
      return Discs.new(kept, period: tally.period, bars: track, shape: SHAPE).all if on_track?

      Discs.new(kept, period: tally.period, bars: series, shape: SHAPE).all
    end

    # A flat ground for the circles on the track, so they spread without lifting.
    def track
      ground = TRACK_Y + SHAPE.lift + (SHAPE.size / 2.0)
      columns = tally.buckets.map do |bucket|
        cx = series.center(bucket.span.index)
        Bars::Column.new(cx: cx, x: cx, top: ground)
      end
      Track.new(columns: columns, width: 0, frame: FRAME.with(bottom: ground))
    end

    def num(value)
      CardLayout::Shapes.num(value)
    end
  end
end
