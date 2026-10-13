module CardLayout
  class StarChart
    # Under the rows: each project's commits this week in its star colour,
    # then the week's total at the right. Every project is named, up to six,
    # and the line wraps to a second one before a name is cut.
    class Legend
      SIZE = 12.5
      GAP = 12
      ROOM2 = WIDTH
      Item = Data.define(:name, :full, :count, :color, :center, :more)

      # dots: each project's mark, for the partial: { x:, y:, color:, center: }.
      attr_reader :height, :dots

      def initialize(chart)
        @chart = chart
        @canvas = chart.canvas
        @palette = chart.palette
        @dots = []
        @total = chart.shows?("totals")
        items = chart.shows?("projects") ? items_of(chart.projects) : []
        @lines = items.any? ? split(items) : [ [], [] ]
        @height = shown? ? 26 + (@lines.last.any? ? 19 : 0) : 0
      end

      def shown?
        @chart.commits.positive? && (@total || @lines.first.any?)
      end

      # Under the rows, or a closing rule when the week has no commits.
      def draw(top)
        return @canvas.draw(:rules, Shapes.rule(LEFT, LEFT + WIDTH, top)) unless shown?

        @canvas.draw(:rules, Shapes.rule(LEFT, LEFT + WIDTH, top))
        first = top + 10 + [ @lines.first.any? ? StarChart.base_in(16, SIZE) : 0, @total ? 0.99 * 13.5 : 0 ].max
        line(@lines.first, first)
        line(@lines.last, top + 10 + 16 + 2 + StarChart.base_in(17, SIZE))
        total(first) if @total
      end

      private

      def items_of(projects)
        items = projects.first(6).map do |project|
          tones = @chart.tones(project.name)
          Item.new(name: project.name, full: project.name, count: project.n, color: tones[@chart.dark ? 0 : 2],
                   center: @chart.dark ? "#FFFFFF" : tones[1], more: false)
        end
        projects.size > 6 ? items + [ Item.new(name: "+#{projects.size - 6} more", full: nil, count: nil, color: nil, center: nil, more: true) ] : items
      end

      def sans(text)
        CardText.width(text, size: SIZE, face: :dm_sans_regular)
      end

      def item_width(item)
        return sans(item.name) if item.more

        8 + 6 + sans(item.name) + 6 + CardText.width(Type.number(item.count), size: 11.5, face: :dm_mono_regular)
      end

      def line_width(items)
        items.sum { |item| item_width(item) } + (GAP * [ items.size - 1, 0 ].max)
      end

      def room1
        @total ? WIDTH - total_width - 16 : WIDTH
      end

      def total_label
        @chart.commits == 1 ? "COMMIT" : "COMMITS"
      end

      def total_width
        CardText.width(Type.number(@chart.commits), size: 13.5, face: :dm_mono_medium) +
          CardText.width(" #{total_label}", size: 11, face: :dm_mono_regular, spacing: 0.88)
      end

      # Two lines keep the biggest projects on the first and the order within
      # each; the split that fits and leaves the most on the first wins. Names
      # are shortened only when no split fits.
      def split(items)
        return [ items, [] ] if line_width(items) <= room1

        best = (1...(1 << items.size)).select(&:odd?).filter_map { |mask| candidate(items, mask) }.max_by(&:last)
        best ? best.first(2) : squeeze(items)
      end

      def candidate(items, mask)
        first, second = items.each_with_index.partition { |_item, i| mask[i] == 1 }.map { |pairs| pairs.map(&:first) }
        return if line_width(first) > room1 || line_width(second) > ROOM2

        score = first.sum { |item| (items.size - items.index(item)) * 10 } - second.sum { |item| items.index(item) }
        [ first, second, score ]
      end

      # As many as fit on the first line, at least one, the rest on the
      # second; then the widest names are shortened until each line fits.
      def squeeze(items)
        k = 0
        x = 0
        while k < items.size
          width = item_width(items[k]) + (k.zero? ? 0 : GAP)
          break if k.positive? && x + width > room1

          x += width
          k += 1
        end
        [ shorten(items.first(k), room1), shorten(items.drop(k), ROOM2) ]
      end

      def shorten(items, room)
        items = items.dup
        60.times do
          break if line_width(items) <= room

          widest = items.reject(&:more).max_by { |item| sans(item.name) }
          break if widest.nil? || sans(widest.name) <= 80

          cut = StarChart.cut(widest.full, [ 80, sans(widest.name) - (line_width(items) - room) - 1 ].max) { |text| sans(text) }
          items[items.index(widest)] = widest.with(name: cut)
        end
        items
      end

      def line(items, baseline)
        items.inject(LEFT) do |x, item|
          next @canvas.put(item.name, :dm_sans_regular, SIZE, x, baseline, @palette[:muted]) + GAP if item.more

          @dots << { x: x + 4, y: baseline - 4.5, color: item.color, center: item.center }
          name_end = @canvas.put(item.name, :dm_sans_regular, SIZE, x + 14, baseline, @palette[:text])
          @canvas.put(Type.number(item.count), :dm_mono_regular, 11.5, name_end + 6, baseline, @palette[:muted]) + GAP
        end
      end

      # The count and its word, ending at the column's edge. SVG drops a
      # leading space, so the word starts one space further on.
      def total(baseline)
        x = LEFT + WIDTH - total_width
        x = @canvas.put(Type.number(@chart.commits), :dm_mono_medium, 13.5, x, baseline, @palette[:title])
        space = CardText.width(" ", size: 11, face: :dm_mono_regular, spacing: 0.88)
        @canvas.put(total_label, :dm_mono_regular, 11, x + space, baseline, @palette[:muted], spacing: 0.08)
      end
    end
  end
end
