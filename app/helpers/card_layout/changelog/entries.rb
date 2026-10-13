module CardLayout
  class Changelog
    # The entries: one row per day with work, then one line for the quiet
    # days. The builder's words set one size for the list, from 22px for a full
    # week up to 42px when one entry carries it, stepping down by half pixels
    # until every row fits. A launch is set a weight heavier on a wash, so the
    # week's news leads.
    class Entries
      ROOM = R - X_HEAD
      LIST_H = FOOT_RULE - LIST_TOP
      WORDS_LS = -0.015
      COUNT_S = 16
      DAY_S = 12
      TAG_W = 72
      TAG_H = 18
      TAG_S = 9.5
      META_GAP = 10
      PAD = 9 # the least room above and below a row
      FOLD_H = 46
      # SHIPPED is filled; PUBLISHED is outlined in the accent; BUILT quietly.
      TAGS = { "shipped" => [ "SHIPPED", :tag_ship, :on_accent ], "published" => [ "PUBLISHED", :tag_pub, :accent ],
               "built" => [ "BUILT", :tag_built, :muted ] }.freeze
      Row = Data.define(:day, :face, :size, :height, :lines, :fill, :content)

      def initialize(layout)
        @layout = layout
        @canvas = layout.canvas
        @palette = layout.palette
        @breakers = {}
      end

      # Draws the list and says how many rows it has, at least one.
      def draw
        days = @layout.days.select(&:active)
        @fold = fold_text
        rows = fit(days)
        tops = place(rows)
        rows.each_with_index { |row, i| draw_row(row, tops[i], tops[i + 1], i.positive? && rows[i - 1]) }
        draw_fold(tops.last, rows.last) if @fold
        [ rows.size, 1 ].max
      end

      private

      # "Mon, Sat · no changes", unless the builder shows only the days they worked.
      def fold_text
        quiet = @layout.days.reject(&:active).map { |day| day.date.strftime("%a") }
        "#{quiet.join(', ')} · no changes" if quiet.any? && @layout.card.week_card.layout == "week"
      end

      def fit(days)
        named = days.count(&:named?)
        rows = []
        { 5 => 22, 4 => 25, 3 => 28, 2 => 34 }.fetch([ named, 5 ].min, 42).step(15.5, -0.5) do |size|
          rows = days.map { |day| day.named? ? words_row(day, size) : count_row(day) }
          @need = rows.sum { |row| row.content + (2 * PAD) } + (@fold ? FOLD_H : 0)
          break if @need <= LIST_H
        end
        rows
      end

      def words_row(day, size)
        face = day.kind == "shipped" ? :inter_semibold : :inter_medium
        lines = breaker(day, face).balance(size, ROOM, 3) || [ Type.cut_words(day.words, face, size, WORDS_LS, ROOM) ]
        height = (size * 1.25).round
        tail = day.total.positive? ? META_GAP + Pills::HEIGHT : [ 0.24 * size, 6 ].max
        Row.new(day: day, face: face, size: size, height: height, lines: lines, fill: @palette[:ink],
                content: [ Type.cap(face, size) + ((lines.size - 1) * height) + tail, 10 + TAG_H ].max)
      end

      def breaker(day, face)
        @breakers[day.date] ||= Lines.new(day.words, face, WORDS_LS)
      end

      # A day the builder wrote nothing for, counted: the short form when the
      # full one would not fit.
      def count_row(day)
        full, short = count_lines(day)
        line = Type.width(full, :inter_regular, COUNT_S) <= ROOM ? full : short
        Row.new(day: day, face: :inter_regular, size: COUNT_S, height: (COUNT_S * 1.3).round,
                lines: [ Type.cut_words(line, :inter_regular, COUNT_S, 0, ROOM) ], fill: @palette[:muted],
                content: [ Type.cap(:inter_regular, COUNT_S) + 6, 10 + TAG_H ].max)
      end

      # "6 commits in wheels-off and openstage", and past two projects "10
      # commits across 6 projects". The number is always the day's total.
      def count_lines(day)
        return [ "", "" ] if day.total.zero?

        commits = "#{Type.number(day.total)} #{'commit'.pluralize(day.total)}"
        names = day.projects.map { |name, _n, _slot| Type.cut_name(name.to_s, 22) }
        across = "#{commits} across #{names.size} projects"
        return [ commits, commits ] unless @layout.shows?("projects")
        return [ "#{commits} in #{names.join(' and ')}", names.size > 1 ? across : commits ] if names.size <= 2

        [ across, across ]
      end

      # Spare height goes to padding, up to a cap that is bigger when fewer
      # rows share the list; what is left sits partly above the first row and
      # partly below the last, so a thin week is centred and calm.
      def place(rows)
        count = [ rows.size, 1 ].max
        spare = LIST_H - @need
        @pad = spare.negative? ? [ 3, PAD + (spare / (2.0 * count)) ].max : PAD
        grow = spare.positive? ? [ spare / (2.0 * count), pad_cap(count) - PAD ].min : 0
        @pad += grow
        at = LIST_TOP + (spare.positive? ? (spare - (grow * 2 * count)) * 0.4 : 0)
        rows.map { |row| at.round.tap { at += row.content + (2 * @pad) } } + [ at.round ]
      end

      def pad_cap(count)
        return 50 if count <= 2

        count <= 4 ? 30 : 22
      end

      def washed?(row)
        row && row.day.kind == "shipped" && row.day.named?
      end

      # Hairlines part the rows, except next to a launch, whose wash parts it.
      # The day sits on the words' baseline, or at its cap line when they are big.
      def draw_row(row, top, bottom, previous)
        frame(row, top, bottom, previous)
        first = top + @pad + Type.cap(row.face, row.size)
        day_baseline = row.size <= 24 ? first : top + @pad + Type.cap(:dm_mono_medium, DAY_S)
        @canvas.put("#{row.day.dow} #{format('%02d', row.day.date.day)}", :dm_mono_medium, DAY_S, X_DAY, day_baseline.round(1),
                    @palette[row.day.named? ? :ink : :muted], spacing: 0.04)
        tag(row.day.kind, (day_baseline + 10).round)
        row.lines.each_with_index do |line, k|
          @canvas.put(line, row.face, row.size, X_HEAD, (first + (k * row.height)).round(1), row.fill,
                      spacing: row.day.named? ? WORDS_LS : 0)
        end
        meta(row, first + ((row.lines.size - 1) * row.height)) if row.day.named? && row.day.total.positive?
      end

      def frame(row, top, bottom, previous)
        @canvas.draw(:rules, Shapes.rule(X_DAY, R, top)) if previous && !washed?(row) && !washed?(previous)
        @canvas.draw(:wash, Shapes.rounded(X_DAY - 14, top + 3, R - X_DAY + 28, bottom - top - 6, 8)) if washed?(row)
      end

      def tag(kind, top)
        text, layer, fill = TAGS.fetch(kind, TAGS["built"])
        @canvas.draw(layer, layer == :tag_ship ? Shapes.rounded(X_DAY, top, TAG_W, TAG_H, 4) : Shapes.outline(X_DAY, top, TAG_W, TAG_H, 4))
        @canvas.put(text, :dm_mono_medium, TAG_S, X_DAY + ((TAG_W - Type.width(text, :dm_mono_medium, TAG_S, 0.1)) / 2),
                    top + (TAG_H / 2.0) + (Type.cap(:dm_mono_medium, TAG_S) / 2), @palette[fill], spacing: 0.1)
      end

      # "16 COMMITS", then the day's projects.
      def meta(row, last_baseline)
        mid = (last_baseline + META_GAP).round + (Pills::HEIGHT / 2.0)
        total = row.day.total
        x = @canvas.put("#{Type.number(total)} #{total == 1 ? 'COMMIT' : 'COMMITS'}", :dm_mono_medium, 10, X_HEAD,
                        mid + (Type.cap(:dm_mono_medium, 10) / 2), @palette[:muted], spacing: 0.1)
        Pills.new(@layout).draw(row.day, x + 14, mid) if @layout.shows?("projects")
      end

      def draw_fold(top, last)
        @canvas.draw(:rules, Shapes.rule(X_DAY, R, top)) if last && !washed?(last)
        @canvas.put(@fold, :inter_regular, 14, X_DAY, (top + (FOLD_H / 2.0) + (Type.cap(:inter_regular, 14) / 2)).round(1),
                    @palette[:muted])
      end
    end
  end
end
