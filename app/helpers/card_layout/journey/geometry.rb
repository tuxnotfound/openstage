module CardLayout
  class Journey
    # The Journey card's chart in card pixels, ported from
    # doc/progress/sources/journey/engine.js. Time runs on a day scale from one
    # unit before the first activity (a day in Week and Month, a month in Year
    # and All), or the period's start if later; a running period stops at
    # today, or at the end of this month in Year and All. The ink line adds up
    # every commit and carries the words; each project's line runs beneath it.
    class Geometry
      LEFT = 100
      RIGHT = 1140
      TOP = 318
      BASE = 552
      # The narrowest bin a circle gets before circles group by a wider unit.
      MIN_BIN = 18

      Marker = Data.define(:x, :y, :items, :shipped, :rising)
      EndBox = Data.define(:x, :y, :w, :h, :num, :word)

      attr_reader :first, :last, :days, :by_day, :scale, :line, :project_lines, :markers, :total

      def initialize(section)
        @section = section
        @period = section.tally.period
        @by_day = %w[week month].include?(@period.range)
        @first, @last = domain
        @days = (@last - @first).to_i + 1
        @line, @project_lines, @total = lines
        @scale = ProgressChart::Scale.new(total, top: TOP, bottom: BASE)
        @line = @line.map { |t, v| [ x_at(t), scale.y(v) ] }
        @project_lines = @project_lines.transform_values { |points| points.map { |t, v| [ x_at(t), scale.y(v) ] } }
        @markers = place_markers
      end

      def self.path(points)
        "M#{points.map { |x, y| "#{Shapes.num(x.round(1))},#{Shapes.num(y.round(1))}" }.join('L')}"
      end

      # The area under the ink line, for the wash.
      def wash_path
        "#{self.class.path(line)}L#{Shapes.num(line.last.first.round(1))},#{BASE}L#{Shapes.num(line.first.first.round(1))},#{BASE}Z"
      end

      def x_at(days_in)
        LEFT + (days_in.to_f / days * (RIGHT - LEFT))
      end

      # The ink line's height at x, or nil past its end.
      def line_y(x)
        return line.first.last if x < line.first.first

        line.each_cons(2) do |(x0, y0), (x1, y1)|
          return x1 == x0 ? y0 : y0 + ((y1 - y0) * (x - x0) / (x1 - x0)) if x.between?(x0, x1)
        end
        nil
      end

      # "380 commits" beside the end dot while the period has room, else above
      # and left of it, clear of the axis when nothing is committed yet.
      def end_box
        @end_box ||= begin
          word = " commit#{'s' unless total == 1}"
          w = Type.width(total.to_s, :inter_semibold, 24) + Type.width(word, :inter_regular, 17)
          ex, ey = line.last
          right = @period.running? && last > @period.today && ex + 10 + w <= RIGHT
          EndBox.new(x: right ? ex + 10 : [ ex - 4, RIGHT ].min - w, y: right ? [ ey - 15, BASE - 4 - 30 ].min : [ 0, ey - 12 - 30 ].max,
                     w: w, h: 30, num: total.to_s, word: word)
        end
      end

      def bins(unit)
        case unit
        when :day then (first..last).map { |day| first_and_last(day, day) }
        when :week then (first - (first.cwday - 1)).step(last, 7).map { |monday| first_and_last(monday, monday + 6) }
        else months
        end
      end

      private

      def domain
        start = @section.tally.first_project_day
        floor = if start.nil? then @period.first
        elsif by_day then start - 1
        else start.beginning_of_month.prev_month
        end
        from = @period.range == "all" ? floor : [ @period.first, floor ].max
        from = @period.first if from > @period.last
        [ from, @period.running? ? (by_day ? @period.today : @period.today.end_of_month) : @period.last ]
      end

      def months
        start = first.beginning_of_month
        out = []
        while start <= last
          out << first_and_last(start, start.end_of_month)
          start = start.next_month
        end
        out
      end

      def first_and_last(from, to)
        [ [ from, first ].max, [ to, last ].min ]
      end

      # [days in, commits so far] at the end of every bin up to today: the ink
      # total, then each project's from the left edge, so a late one starts on
      # the baseline.
      def lines
        snapshots = running_sums
        total = [ [ 0, 0 ] ] + snapshots.map { |t, sums| [ t, sums.values.sum ] }
        keys = @section.project ? [] : snapshots.flat_map { |_t, sums| sums.keys }.uniq
        projects = keys.index_with { |key| [ [ 0, 0 ] ] + snapshots.map { |t, sums| [ t, sums.fetch(key, 0) ] } }
        [ total, projects, total.last.last ]
      end

      def running_sums
        counts = @section.tally.day_counts
        repos = @section.selected.map(&:repo)
        sums = Hash.new(0)
        bins(by_day ? :day : :week).filter_map do |from, to|
          next if from > @period.today

          to = [ to, @period.today ].min
          (from..to).each { |day| counts.fetch(day, {}).each { |key, n| sums[key] += n if repos.empty? || repos.include?(key) } }
          [ (to - first).to_i + 1, sums.dup ]
        end
      end

      def place_markers
        unit = marker_unit
        ex = line.last.first
        bins(unit).filter_map do |from, to|
          items = @section.tally.items.select { |item| item.date.between?(from, to) }
          next if items.empty?

          upto = [ to, @period.today ].min
          x = [ x_at((from - first).to_i + (((upto - from).to_i + 1) / 2.0)), ex ].min
          rising = line_y([ x + 4, ex ].min).to_f < line_y([ x - 4, line.first.first ].max).to_f - 0.01
          Marker.new(x: x, y: line_y(x) || line.last.last, items: items, shipped: items.any?(&:shipped?), rising: rising)
        end
      end

      def marker_unit
        per_day = (RIGHT - LEFT).to_f / days
        return :month if per_day * 7 < MIN_BIN
        return :week if by_day && per_day < MIN_BIN

        by_day ? :day : :week
      end
    end
  end
end
