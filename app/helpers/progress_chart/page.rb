module ProgressChart
  # The progress section's Bars chart, laid out for the page. The SVG is drawn
  # in a 640 by 300 box that scales with its column; the HTML laid over it
  # (axis labels, discs and the hover columns) is placed in percentages of
  # that box, so it stays put at any width.
  class Page
    WIDTH = 640
    HEIGHT = 300
    FRAME = Bars::Frame.new(left: 34, right: 632, top: 34, bottom: 244)
    AXIS_Y = 262
    SHAPE = Discs::Shape.new(size: 18, pill: 30, gap: 3, lift: 4)
    LEGEND_SIZE = 5

    Tick = Data.define(:value, :top)
    Label = Data.define(:text, :left, :tone)
    # One hover column per bucket, with what its tooltip says.
    Column = Data.define(:left, :width, :title, :total, :rows, :notes)
    Row = Data.define(:name, :n, :color, :repo)
    Note = Data.define(:mark, :title, :shipped)

    attr_reader :section

    def initialize(section)
      @section = section
      @bars = Bars.new(tally.buckets, repos: tally.projects.all.map(&:repo), colors: colors, frame: FRAME)
      @discs = Discs.new(section.pick.kept, period: tally.period, bars: @bars, shape: SHAPE)
    end

    def fills
      @bars.fills
    end

    def discs
      @discs.all
    end

    def ticks
      @bars.scale.ticks.map { |value| Tick.new(value: value, top: top(@bars.scale.y(value))) }
    end

    def grid_path
      @bars.scale.ticks.drop(1).map { |value| "M#{FRAME.left},#{num(@bars.scale.y(value))}H#{FRAME.right}" }.join
    end

    def base_path
      "M#{FRAME.left},#{FRAME.bottom}H#{FRAME.right}"
    end

    def labels
      tally.period.buckets.filter_map do |bucket|
        text = section.labels.axis(bucket)
        Label.new(text: text, left: left(@bars.center(bucket.index)), tone: tone(bucket)) if text.present?
      end
    end

    def columns
      tally.buckets.map do |bucket|
        span = bucket.span
        Column.new(left: left(FRAME.left + (@bars.slot * span.index)), width: left(FRAME.left + @bars.slot) - left(FRAME.left),
                   title: section.labels.bucket_title(span),
                   total: span.future ? "Still ahead" : "#{bucket.total} #{'commit'.pluralize(bucket.total)}",
                   rows: rows(bucket.counts), notes: bucket.items.map { |item| note(item) })
      end
    end

    # The period's projects, busiest first; nil without a choice to make.
    def legend
      rows = rows(tally.totals.counts).select(&:repo)
      rows if section.project.nil? && rows.size > 1
    end

    def label_top
      top(AXIS_Y)
    end

    def left(x)
      (100.0 * x / WIDTH).round(1)
    end

    def top(y)
      (100.0 * y / HEIGHT).round(1)
    end

    def disc_left(disc)
      left(disc.x)
    end

    def disc_top(disc)
      top(disc.cy)
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

    def colors
      colors = tally.projects.all.to_h { |project| [ project.repo, Palette.project_color(project.rank) ] }
      colors.default = Palette.project_color(nil)
      colors
    end

    def rows(counts)
      projects = tally.projects
      counts.select { |_repo, n| n.positive? }.sort_by { |repo, n| [ -n, repo.to_s ] }.map do |repo, n|
        project = repo && projects.find(repo)
        Row.new(name: project&.name || "No repo", n: n, color: Palette.project_color(project&.rank), repo: repo)
      end
    end

    def note(item)
      number = section.pick.kept.index(item)
      Note.new(mark: number ? (number + 1).to_s : "·", title: item.title, shipped: item.shipped?)
    end

    # On the Year axis a label names a month, so the month holding today is
    # the current one.
    def tone(bucket)
      today = tally.period.today
      if tally.period.range == "year"
        month = (bucket.monday + 3).all_month
        return :now if month.cover?(today)

        return month.first > today ? :future : :past
      end
      bucket.current ? :now : (bucket.future ? :future : :past)
    end

    def num(value)
      CardLayout::Shapes.num(value)
    end
  end
end
