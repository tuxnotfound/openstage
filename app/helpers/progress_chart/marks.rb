module ProgressChart
  # What a chart filter's chart (Compare) marks on its points: the shipped
  # and published entries its page lists, one mark per project and point.
  # A mark sits on its project's line of the first number drawn, in the
  # pages' order, that the project has; on the axis where the project has
  # no line, and for an entry with no project, which wears ink. An entry
  # before the chart's first point has no mark.
  class Marks
    # The badges of its entries (TallyService::Item#badge), the one a mark
    # wears first: a milestone, then something shipped, then something
    # published.
    BADGES = %i[milestone shipped published].freeze

    # key: its project's repo, nil for none; number: the key of the number
    # whose line it sits on, nil on the axis; left and top: where, in percent
    # of the chart from its top left; items: its TallyService::Items, newest
    # first.
    Mark = Data.define(:key, :number, :color_class, :column, :left, :top, :items) do
      def badge
        BADGES.find { |badge| items.any? { |item| item.badge == badge } }
      end
    end

    def initialize(chart, items)
      @chart = chart
      @items = items
    end

    def all
      placed = @items.filter_map do |item|
        bucket = @chart.window.bucket_for(item.date)
        [ item.repo_name, bucket.index, item ] if bucket
      end
      placed.group_by { |key, column, _| [ key, column ] }.map { |(key, column), group| mark(key, column, group.map(&:last).reverse) }
    end

    private

    def mark(key, column, items)
      line = line_of(key)
      left, top = @chart.spot(column, line)
      Mark.new(key: key, number: line&.number&.key, color_class: color_of(key, line), column: column, left: left, top: top, items: items)
    end

    def line_of(key)
      return unless key

      @chart.lines.select { |line| line.repo == key }.min_by { |line| @chart.lined.index(line.number) }
    end

    # Its line's colour; on the axis its project's, while it has one.
    def color_of(key, line)
      line&.color_class || (@chart.every_line.find { |each| each.repo == key }&.color_class if key) || Palette::INK_CLASS
    end
  end
end
