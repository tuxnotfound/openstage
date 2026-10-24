module ProgressChart
  # The public page's chart: one line per project through each point's
  # commits, or each day's 7-day average over the last 30 days, with the
  # listed entries as numbered discs on their project's line. Drawn in a 1000
  # by 280 box that stretches to its column; the HTML laid over it is placed
  # in percentages, so it stays put at any width.
  class Trend
    WIDTH = 1000
    HEIGHT = 280
    # Days in the 30-day view's average.
    AVERAGE = 7
    # Room over the top gridline, so a peak and the disc on it stay inside.
    HEADROOM = 1.1

    # values: one per point, in the window's order.
    Line = Data.define(:repo, :name, :rank, :total, :values)
    Tick = Data.define(:value, :top)
    # rank: the project's colour; nil for an entry with no project.
    Disc = Data.define(:number, :item, :rank, :left, :top)
    Row = Data.define(:name, :rank, :value)
    # mark: where the point sits inside the column, in percent of its width.
    Column = Data.define(:left, :width, :mark, :title, :rows, :notes)

    attr_reader :section

    # discs: the weekly emails number the section's picks on their lines;
    # the pages draw the lines alone.
    def initialize(section, discs: false)
      @section = section
      @show_discs = discs
    end

    # The entries that get discs, in date order.
    def items
      section.pick.kept
    end

    # Only the page's 30-day window averages; a calendar week counts each day.
    def average?
      period.range == "30d"
    end

    # The projects in view with commits in the window, busiest of all time first.
    def lines
      @lines ||= begin
        counts = tally.totals.counts
        tally.projects.all.select { |project| counts.fetch(project.repo, 0).positive? }.map do |project|
          Line.new(repo: project.repo, name: project.name, rank: project.rank, total: counts[project.repo], values: values_for(project.repo))
        end
      end
    end

    # [d, rank] per line, the busiest last so it draws on top.
    def paths
      lines.reverse.map do |line|
        [ line.values.each_with_index.map { |value, i| "#{i.zero? ? 'M' : 'L'}#{num(x(i))} #{num(y(value))}" }.join(" "), line.rank ]
      end
    end

    # The gridlines over the baseline, with their labels.
    def ticks
      scale.drop(1).map { |value| Tick.new(value: value, top: top(value)) }
    end

    def discs
      @discs ||= @show_discs ? Placement.new(self).discs : []
    end

    # The first point, the middle one and today, under the chart.
    def axis
      buckets = period.buckets
      return [ labels.axis(buckets.first), "Today" ] if buckets.size < 3

      [ labels.axis(buckets.first), labels.axis(buckets[buckets.size / 2]), "Today" ]
    end

    # One hover strip per point, from halfway to the point before to halfway
    # to the next.
    def columns
      count = period.buckets.size
      period.buckets.map do |bucket|
        i = bucket.index
        from = i.zero? ? 0 : (x(i - 1) + x(i)) / 2
        to = i == count - 1 ? WIDTH : (x(i) + x(i + 1)) / 2
        Column.new(left: pct(from), width: pct(to - from), mark: (100.0 * (x(i) - from) / (to - from)).round(1),
                   title: labels.bucket_title(bucket), rows: rows_at(i), notes: discs.select { |disc| point_of(disc.item) == i })
      end
    end

    def aria_label
      what = average? ? "7-day average of commits per day" : "Commits per #{labels.unit_word}"
      "#{what} by project, #{labels.words}"
    end

    def note
      average? ? "A 7-day average of commits per day, one line per project." : "Commits per #{labels.unit_word}, one line per project."
    end

    def empty_note
      "No commits #{labels.word}#{" for #{section.selection_name}" if section.filtered?}."
    end

    def labels_for(bucket)
      labels.axis(bucket)
    end

    # The point a dated entry falls on; the last one when it is outside.
    def point_of(item)
      period.bucket_for(item.date)&.index || (period.buckets.size - 1)
    end

    def x(index)
      count = period.buckets.size
      count == 1 ? WIDTH / 2.0 : index * WIDTH.to_f / (count - 1)
    end

    # A value's height, in percent from the top of the chart.
    def top(value)
      (100.0 - (100.0 * value / ceiling)).round(2)
    end

    def tally
      section.tally
    end

    private

    def period
      tally.period
    end

    def labels
      section.labels
    end

    def values_for(repo)
      return tally.buckets.map { |bucket| bucket.counts.fetch(repo, 0) } unless average?

      period.buckets.map do |bucket|
        (0...AVERAGE).sum { |back| tally.day_counts.fetch(bucket.first - back, {}).fetch(repo, 0) } / AVERAGE.to_f
      end
    end

    # The lines with commits at a point, busiest first.
    def rows_at(index)
      lines.select { |line| line.values[index].positive? }.sort_by { |line| -line.values[index] }.map do |line|
        Row.new(name: line.name, rank: line.rank, value: average? ? format("%.1f", line.values[index]) : line.values[index])
      end
    end

    # Nice steps over the busiest point; whole commits unless averaged.
    def scale
      @scale ||= Scale.ticks([ lines.flat_map(&:values).max.to_f, average? ? 1 : 4 ].max)
    end

    def ceiling
      scale.last * HEADROOM
    end

    def y(value)
      HEIGHT * (1 - (value / ceiling))
    end

    def pct(value)
      (100.0 * value / WIDTH).round(2)
    end

    # 12.5 or 12, never 12.0, so the paths stay short.
    def num(value)
      rounded = value.to_f.round(2)
      rounded == rounded.to_i ? rounded.to_i.to_s : rounded.to_s
    end

    # Each listed entry as a disc on its project's line at its point. An
    # entry with no project stands on the busiest line there, in no colour; one
    # whose project has no line stands on the baseline. A disc that would
    # cover another moves up, or down and aside when there is no room.
    class Placement
      def initialize(chart)
        @chart = chart
        @placed = []
      end

      def discs
        @chart.items.each_with_index.map do |item, k|
          index = @chart.point_of(item)
          project = item.repo_name && @chart.tally.projects.find(item.repo_name)
          line = project ? @chart.lines.find { |own| own.repo == project.repo } : @chart.lines.max_by { |any| any.values[index] }
          left, top = clear((100.0 * @chart.x(index) / WIDTH).clamp(2, 98), (line ? @chart.top(line.values[index]) : 100).clamp(6, 94))
          Disc.new(number: k + 1, item: item, rank: project&.rank, left: left.round(2), top: top.round(2))
        end
      end

      private

      def clear(left, top)
        20.times do
          break unless @placed.any? { |other_left, other_top| (other_left - left).abs < 4 && (other_top - top).abs < 11 }

          if top >= 18
            top -= 12
          else
            top = [ top + 24, 94 ].min
            left = [ left + 2, 98 ].min
          end
        end
        @placed << [ left, top ]
        [ left, top ]
      end
    end
  end
end
