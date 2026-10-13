module CardLayout
  class Changelog
    # The rail under who: the seven days at a glance, the week's four numbers
    # with the change from last week, and the line counts. The groups stack
    # from the top with one even gap, so spare height collects once under the
    # numbers instead of opening holes between them.
    class Rail
      GAP = 40
      CELL = 32
      CELL_GAP = 5
      CELL_H = 30
      KEY_ROW = 40
      CELLS = %i[cell1 cell2 cell3 cell4].freeze

      def initialize(layout)
        @layout = layout
        @card = layout.card
        @canvas = layout.canvas
        @palette = layout.palette
      end

      def draw(bottom)
        bottom = strip(bottom) if @layout.shows?("activity")
        if @layout.shows?("totals")
          bottom = numbers(bottom)
          code(bottom + 24)
        else
          code(below(bottom, 4))
        end
      end

      private

      # The baseline of a group's first line, one gap below what is above it,
      # or the top line when nothing is.
      def below(bottom, lift)
        bottom ? (bottom + GAP + lift).round : HEAD_B
      end

      # A cell's strength is the day's commits on one fixed scale (1-2, 3-7,
      # 8-15, 16+), so cards compare across weeks. A day with a post and no
      # commits is outlined in the accent, and a key says so.
      def strip(bottom)
        caption = below(bottom, 4)
        @canvas.put("COMMITS PER DAY", :dm_mono_medium, 9.5, L, caption, @palette[:muted], spacing: 0.12)
        top = caption + 12
        posts = @layout.days.each_with_index.count { |day, i| cell(day, L + (i * (CELL + CELL_GAP)), top) }
        posts.positive? ? key(top + CELL_H + 37) : top + CELL_H + 16
      end

      # True for a day with a post and no commits.
      def cell(day, x, top)
        level = [ 1, 3, 8, 16 ].count { |least| day.total >= least }
        if level.positive? then @canvas.draw(CELLS[level - 1], Shapes.rounded(x, top, CELL, CELL_H, 5))
        elsif day.active then @canvas.draw(:cell_post, Shapes.rounded(x + 0.75, top + 0.75, CELL - 1.5, CELL_H - 1.5, 4.5))
        else @canvas.draw(:cell_empty, Shapes.outline(x, top, CELL, CELL_H, 5))
        end
        letter = day.dow[0]
        @canvas.put(letter, :dm_mono_medium, 10, x + (CELL / 2.0) - (Type.width(letter, :dm_mono_medium, 10) / 2), top + CELL_H + 16,
                    @palette[day.active ? :muted : :faint])
        level.zero? && day.active
      end

      def key(baseline)
        @canvas.draw(:cell_post, Shapes.rounded(L + 0.75, baseline - 10 + 0.75, 14.5, 9.5, 3))
        @canvas.put("Outlined: a post, no commits", :inter_regular, 11, L + 24, baseline, @palette[:muted])
        baseline
      end

      # Without the change from last week, its column goes and the numbers
      # move to the edge.
      def numbers(bottom)
        top = bottom ? (bottom + GAP + 12).round : HEAD_B + 9
        before = @layout.shows?("compare") ? @card.previous&.totals : nil
        right = before ? COL_R - 58 : COL_R
        week = @card.week_card.week_start
        @canvas.put_end("W#{week.cweek}", :dm_mono_medium, 10, right, top - 9, @palette[:muted], spacing: 0.12)
        @canvas.put_end("VS W#{(week - 7).cweek}", :dm_mono_medium, 10, COL_R, top - 9, @palette[:muted], spacing: 0.12) if before
        @canvas.draw(:rules_strong, Shapes.rule(L, COL_R, top))
        facts(before).each_with_index { |fact, i| number(*fact, top + (i * KEY_ROW), right, i.positive?) }
        top + (4 * KEY_ROW)
      end

      def facts(before)
        now = @card.totals
        [ [ "Commits", now.commits, before&.commits ], [ "Days active", now.active_days, before&.active_days ],
          [ "Shipped", now.shipped, before&.shipped ], [ "Published", now.published, before&.published ] ]
      end

      # Every change prints as a plain count with a true minus sign: "+42",
      # "−16", "±0". A percent would turn a quiet week into "−80%". Gains take
      # the accent; drops and ties stay muted, honest without shouting.
      def number(label, value, was, top, right, ruled)
        @canvas.draw(:rules, Shapes.rule(L, COL_R, top)) if ruled
        baseline = top + (KEY_ROW / 2) + (Type.fig(:inter_figures, 22) / 2)
        @canvas.put(label, :inter_regular, 14, L, baseline, @palette[:muted])
        @canvas.put_end(Type.number(value), :inter_figures, 22, right, baseline, @palette[:ink], spacing: -0.01)
        return if was.nil?

        change = value - was
        @canvas.put_end(signed(change), :dm_mono_medium, 12, COL_R, baseline, @palette[change.positive? ? :accent : :muted])
      end

      def signed(change)
        return "±0" if change.zero?

        "#{change.positive? ? '+' : '−'}#{Type.number(change.abs)}"
      end

      # A footnote the editor can hide: many investors and clients read lines
      # of code as a vanity number.
      def code(baseline)
        code = @card.extras.code
        return unless @layout.shows?("code") && code

        x = @canvas.put("+#{Type.number(code.additions)}", :dm_mono_medium, 11, L, baseline, @palette[:muted])
        x = @canvas.put("−#{Type.number(code.deletions)}", :dm_mono_medium, 11, x + 7, baseline, @palette[:muted])
        @canvas.put("lines · #{Type.number(code.files)} files", :dm_mono_regular, 11, x + 7, baseline, @palette[:faint])
      end
    end
  end
end
