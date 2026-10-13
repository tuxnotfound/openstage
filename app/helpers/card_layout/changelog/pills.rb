module CardLayout
  class Changelog
    # A day's projects after its commit count, as pills: a dot in the
    # project's colour, its name and, when the day has more than one, its
    # commits. What does not fit is counted in words, "+3 projects", never a
    # bare "+3" that could be commits.
    class Pills
      HEIGHT = 20
      SIZE = 11
      Pill = Data.define(:name, :count, :color, :width)

      def initialize(layout)
        @canvas = layout.canvas
        @palette = layout.palette
      end

      def draw(day, x, mid)
        pills = day.projects.map { |name, n, slot| pill(name.to_s, n, slot, day.projects.size > 1) }
        shown = pills.size
        shown -= 1 while shown.positive? && x + width_of(pills, shown) > R
        at = x.round
        top = (mid - (HEIGHT / 2.0)).round
        pills.first(shown).each { |pill| at = draw_pill(pill, at, top, mid) + 6 }
        return if shown == pills.size

        @canvas.put(more(pills.size - shown), :dm_mono_regular, SIZE, shown.positive? ? at + 4 : at,
                    mid + (Type.cap(:dm_mono_regular, SIZE) / 2), @palette[:muted])
      end

      private

      def pill(name, commits, slot, counted)
        label = Type.cut_name(name, 22)
        count = Type.number(commits) if counted
        width = 8 + 6 + 6 + Type.width(label, :dm_mono_regular, SIZE) + (count ? 5 + Type.width(count, :dm_mono_medium, SIZE) : 0) + 8
        color = slot ? WeekCardsHelper::PROJECT_COLORS.fetch(slot, WeekCardsHelper::OTHER_COLOR) : WeekCardsHelper::OTHER_COLOR
        Pill.new(name: label, count: count, color: color, width: width.round)
      end

      def more(count)
        "+#{count} #{'project'.pluralize(count)}"
      end

      def width_of(pills, shown)
        hidden = pills.size - shown
        pills.first(shown).sum(&:width) + ([ shown - 1, 0 ].max * 6) +
          (hidden.positive? ? (shown.positive? ? 10 : 0) + Type.width(more(hidden), :dm_mono_regular, SIZE) : 0)
      end

      # Returns where the pill ends.
      def draw_pill(pill, x, top, mid)
        baseline = mid + (Type.cap(:dm_mono_regular, SIZE) / 2)
        @canvas.draw(:pills, Shapes.rounded(x, top, pill.width, HEIGHT, HEIGHT / 2.0))
        @canvas.dot(x + 11, top + 10, 3, pill.color)
        name_end = @canvas.put(pill.name, :dm_mono_regular, SIZE, x + 20, baseline, @palette[:pill_text])
        @canvas.put(pill.count, :dm_mono_medium, SIZE, name_end + 5, baseline, @palette[:ink]) if pill.count
        x + pill.width
      end
    end
  end
end
