module CardLayout
  class PixelStage
    # Each day's tower, one bevelled block per commit with the busiest
    # project at the bottom, and the callout above it. A tower must leave room
    # under its callout for its flag, mast or player: if a day cannot fit at
    # five blocks a row, every block in the week stands for more commits; past
    # that, the day's headline gives up lines.
    class Towers
      BOX_W = 142
      BOX_TOP = 104

      def initialize(stage)
        @stage = stage
        @days = stage.days
        @busiest = @days.map(&:total).max || 0
      end

      def draw
        @days.each { |day| day.box = box(day, 6) if day.has? && !day.auto }
        lay_out
        @days.each { |day| tower(day) }
      end

      private

      def box(day, max_lines)
        headline = Headline.new(day.text, BOX_W - 28, max_lines)
        lh = (headline.size * 1.22).round
        { x: @stage.snap(day.cx - (BOX_W / 2.0)), y: BOX_TOP, w: BOX_W, h: ((28 + (headline.lines.size * lh) + 10) / P.to_f).ceil * P,
          size: headline.size, lh: lh, lines: headline.lines }
      end

      def lay_out
        @per_row, @per = 2, 1
        loosen
        @caps = {}
        result = nil
        60.times do
          result = attempt
          bad = result.index { |fits, _layout| !fits }
          break unless bad
          next @per += 1 if @per < @busiest
          break unless shorten(bad)
        end
        @stage.per = @per
        @days.zip(result) { |day, (_fits, layout)| layout.each { |key, value| day[key] = value } }
      end

      def attempt
        @days.each { |day| day.units = units(day.counts) }
        fit = TowerFit.new(@stage, @per_row)
        @days.map { |day| fit.lay(day, (day.box ? day.box[:y] + day.box[:h] : 96) + 12) }
      end

      # The last resort: a line off the day's headline, and blocks back to one
      # commit each. False when the headline cannot give more.
      def shorten(index)
        cap = (@caps[index] || 6) - 1
        return false if @days[index].box.nil? || cap < 2

        @caps[index] = cap
        @days[index].box = box(@days[index], cap)
        @per = 1
        loosen
        true
      end

      # More blocks a row, up to five, then more commits a block, until the
      # busiest day stands ten rows or fewer.
      def loosen
        while (@busiest / @per.to_f / @per_row).ceil > 10
          @per_row < 5 ? @per_row += 1 : @per += 1
        end
      end

      # The day's blocks as colours, busiest project first. When a block stands
      # for several commits, the remainders go to the projects that lost most.
      def units(counts)
        merged = counts.each_with_object(Hash.new(0)) { |(name, n), sum| sum[@stage.merged(name)] += n if n.positive? }
        entries = merged.each_with_index.sort_by { |(name, n), i| [ -n, @stage.rank(name), i ] }.map(&:first)
        return entries.flat_map { |name, n| [ @stage.color_of(name) ] * n } if @per == 1

        shares(entries).flat_map { |share| [ @stage.color_of(share[:name]) ] * share[:k] }
      end

      def shares(entries)
        shares = entries.map { |name, n| { name: name, q: n / @per.to_f, k: [ 1, n / @per ].max } }
        left = [ entries.size, ((entries.sum(&:last) / @per.to_f) + 0.5).floor ].max - shares.sum { |share| share[:k] }
        shares.each_with_index.sort_by { |share, i| [ -(share[:q] - share[:q].floor), i ] }.each do |share, _i|
          break unless left.positive?
          next unless share[:q] > share[:k]

          share[:k] += 1
          left -= 1
        end
        shares
      end

      def tower(day)
        size = @stage.block_size
        @stage.put(:ground, @stage.ground[:grass], @stage.rect(day.left - P, GY, day.tw + (2 * P), P)) if day.units.any?
        day.units.each_with_index do |color, j|
          row = j / day.cols
          col = j % day.cols
          col += day.cols - day.k if day.mirror && day.k.positive? && row == day.rows - 1
          x, y = day.left + (col * size), GY - ((row + 1) * size)
          @stage.put(:t_base, color, @stage.rect(x, y, size, size))
          @stage.put(:t_hi, Paint.mix(color, "#FFFFFF", 0.38), @stage.rect(x, y, size, P) + @stage.rect(x, y + P, P, size - P))
          @stage.put(:t_lo, Paint.mix(color, "#000000", 0.32), @stage.rect(x, y + size - P, size, P) + @stage.rect(x + size - P, y, P, size - P))
        end
      end
    end
  end
end
