module CardLayout
  class PixelStage
    # The strip along the bottom: next week's goal and the builder's link,
    # then the key ("1 BLOCK = 1 COMMIT" and each project's colour) and the
    # series mark.
    class Strip
      KEY_Y = 611

      def initialize(stage)
        @stage = stage
        @card = stage.card
      end

      def draw
        @stage.put(:strip, "#000000", rect(0, 578, 1200, 52), @stage.dark ? 0.45 : 0.32)
        goal
        series = "OPENSTAGE · W#{@card.week_card.week_start.cweek}/#{@card.week_card.week_start.cwyear}"
        @stage.text(series, x: 1182 - wide(series, 8), y: KEY_Y, w: wide(series, 8), align: "right", size: 8, color: "#FFE7C2")
        key(1182 - wide(series, 8) - 24)
      end

      private

      def rect(*box) = @stage.rect(*box)
      def wide(text, size) = @stage.wide(text, size)

      def link
        "openstage.dev/#{@card.user.username}"
      end

      # The goal steps down from 18px to 14px, then is cut, so the link is
      # never cut.
      def goal
        size = wide(link, 16) <= 480 ? 16 : 12
        link_x = 1182 - wide(link, size)
        @stage.text(link, x: link_x, y: 585 + ((16 - size) / 2.0), w: wide(link, size), align: "right", size: size)
        goal = CardText.clean(@card.week_card.next_goal)
        return unless @stage.shows?("goal") && goal.present?

        @stage.text("NEXT", x: 18, y: 585, size: 16, color: "#FFD54A")
        @stage.put(:strip, "#FFD54A", rect(86, 587, 4, 12) + rect(90, 589, 4, 8) + rect(94, 591, 4, 4))
        room = link_x - 24 - 108
        goal_size = 18
        goal_size -= 1 while goal_size > 14 && @stage.pixelify(goal, goal_size, 600) > room
        @stage.text(clip(goal, room, goal_size), x: 108, y: 583 + ((18 - goal_size) / 2.0), w: room + 8, size: goal_size, lh: 22,
                                                 face: :pixelify_semibold)
      end

      def clip(text, room, size)
        return text if @stage.pixelify(text, size, 600) <= room

        cut = text.dup
        cut = cut[0...-1] while cut.length > 1 && @stage.pixelify("#{cut.sub(/[\s·-]+\z/, '')}…", size, 600) > room
        "#{cut.sub(/[\s·-]+\z/, '')}…"
      end

      def key(limit)
        per = @stage.per
        label = @stage.projects.any? ? "1 BLOCK = #{per} COMMIT#{'S' unless per == 1}" : "1 FIRE = 1 DAY OFF"
        @stage.text(label, x: 18, y: KEY_Y, size: 8, color: "#FFE7C2")
        legend(18 + wide(label, 8) + 16, limit) if @stage.shows?("projects")
      end

      # Up to four projects with their commits, then "+N MORE" with a swatch
      # for each of the next three.
      def legend(x, limit)
        projects = @stage.projects
        shown = 0
        projects.each do |name, n|
          name_w = @stage.pixelify(name, 13).ceil
          width = 16 + name_w + 6 + wide(n.to_s, 8) + 18
          rest = projects.size - shown - 1
          rest_w = rest.positive? ? 16 + ([ rest, 3 ].min * 12) + wide("+#{rest} MORE", 8) : 0
          break if shown >= 4 || x + width + rest_w > limit

          swatch(x, @stage.color_of(name), 10)
          @stage.text(name, x: x + 16, y: 606, w: 400, size: 13, lh: 16, face: :pixelify_medium)
          @stage.text(n.to_s, x: x + 16 + name_w + 6, y: KEY_Y, size: 8)
          x += width
          shown += 1
        end
        more(x, projects.drop(shown))
      end

      def more(x, rest)
        return if rest.empty?

        rest.first(3).each_with_index { |(name, _n), i| swatch(x + (i * 12), @stage.color_of(name), 8) }
        @stage.text("+#{rest.size} MORE", x: x + ([ rest.size, 3 ].min * 12) + 4, y: KEY_Y, size: 8, color: "#FFE7C2")
      end

      def swatch(x, color, size)
        @stage.put(:strip, color, rect(x, 610, size, size))
        @stage.put(:strip, Paint.mix(color, "#FFFFFF", 0.4), rect(x, 610, size, 2) + rect(x, 612, 2, size - 2))
        @stage.put(:strip, Paint.mix(color, "#000000", 0.3), rect(x + 2, 608 + size, size - 2, 2) + rect(x + size - 2, 612, 2, size - 4))
      end
    end
  end
end
