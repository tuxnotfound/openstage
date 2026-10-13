module CardLayout
  class PixelStage
    # The HUD along the top: the builder's picture, name, handle and level,
    # the week, and three counters with the scene's own icons. Then the strip
    # along the bottom: next week's goal, the link, and the key.
    class Hud
      SHIPPED_ICON = { "y" => "#FFD54A", "p" => "#D9DCEB", "f" => "#FFCB2E", "F" => "#E0950F" }.freeze
      POSTED_ICON = { "r" => "#FF4D4D", "p" => "#D9DCEB", "a" => "#7FD4FF" }.freeze

      def initialize(stage)
        @stage = stage
        @dark = stage.dark
        @shade = @dark ? "#000000" : "#1B1F3B"
        @card = stage.card
      end

      def draw
        picture
        week
        identity
        counters if @stage.shows?("totals")
        Strip.new(@stage).draw
      end

      private

      def rect(*box) = @stage.rect(*box)
      def wide(text, size) = @stage.wide(text, size)

      def picture
        return unless avatar?

        @stage.put(:hud, @shade, rect(16, 12, 92, 92), @dark ? 0.45 : 0.3)
        @stage.put(:hud, @dark ? "#03040E" : "#1B1F3B", rect(12, 8, 92, 92))
        @stage.put(:hud, "#FFFFFF", rect(16, 12, 84, 84))
      end

      def avatar?
        @stage.shows?("avatar") && @card.user.avatar_url.present?
      end

      def week_title
        "WEEK #{@card.week_card.week_start.cweek}"
      end

      def date_line
        first, last = @card.week_card.week_start, @card.week_card.week_start + 6
        dates = if first.year != last.year then "#{first.strftime('%b %-d, %Y')} – #{last.strftime('%b %-d, %Y')}"
        elsif first.month != last.month then "#{first.strftime('%b %-d')} – #{last.strftime('%b %-d, %Y')}"
        else "#{first.strftime('%b %-d')} – #{last.strftime('%-d, %Y')}"
        end
        dates.upcase
      end

      def week
        @stage.text(week_title, x: 300, y: 14, w: 600, align: "center", size: 32, shadow: @stage.hard_shadow(32, @shade))
        ink, shade = @stage.sky_ink(58, "#FFE7C2")
        @stage.text(date_line, x: 300, y: 56, w: 600, align: "center", size: 16, color: ink, shadow: shade && @stage.hard_shadow(16, shade))
      end

      # The name and the handle fit between the picture and the week title.
      # Without the name, the handle takes its place.
      def identity
        left = avatar? ? 124 : 20
        title_left = 600 - (wide(week_title, 32) / 2)
        name_max = title_left - 24 - left
        handle_max = [ title_left, 600 - (wide(date_line, 16) / 2) ].min - 24 - left
        first = @stage.shows?("name") ? (@card.user.display_name.presence || @card.user.username).to_s.upcase : handle
        name(first, left, name_max) if first.present?
        second(left, handle_max, first == handle)
      end

      def handle
        "@#{@card.user.github_username}" if @stage.shows?("github") && @card.user.github_username.present?
      end

      def name(text, left, room)
        size = [ 28, 24 ].find { |s| wide(text, s) <= room } || 16
        @stage.text(clip(text, room, size), x: left, y: size == 16 ? 26 : 20, size: size, shadow: @stage.hard_shadow(size, @shade))
      end

      # "@handle · LV 29": the level is how many weeks the builder has been building.
      def second(left, room, handle_moved)
        building = @card.extras.building if @stage.shows?("building")
        tail = building ? " · LV #{building.week}" : ""
        shown = handle_moved ? nil : handle
        line = shown ? clip(shown, room - wide(tail, 8), 8) + tail : tail.delete_prefix(" · ")
        return if line.empty?

        ink, shade = @stage.sky_ink(58)
        @stage.text(line, x: left, y: 62, size: 8, color: ink, shadow: shade && @stage.hard_shadow(8, shade))
      end

      def clip(text, room, size)
        return text if wide(text, size) <= room

        cut = text.dup
        cut = cut[0...-1] while cut.length > 1 && wide("#{cut.sub(/[\s·-]+\z/, '')}…", size) > room
        "#{cut.sub(/[\s·-]+\z/, '')}…"
      end

      def counters
        top = @stage.projects.any? ? @stage.color_of(@stage.projects.first.first) : OTHER
        totals = @card.totals
        items = [ [ "COMMITS", format("%03d", totals.commits), Sprites::ICON_BLOCK, block_icon(top) ],
                  [ "SHIPPED", totals.shipped.to_s, Sprites::ICON_FLAG, SHIPPED_ICON ], [ "POSTED", totals.published.to_s, Sprites::ICON_MAST, POSTED_ICON ] ]
        widths = items.map { |_label, value, _icon, _palette| 24 + 6 + wide(value, 24) }
        x = 1184 - widths.sum - (28 * (items.size - 1))
        items.each_with_index do |item, i|
          counter(x, widths[i], *item, i == 1 && totals.shipped.positive?)
          x += widths[i] + 28
        end
      end

      def block_icon(color)
        { "h" => Paint.mix(color, "#FFFFFF", 0.38), "b" => color, "s" => Paint.mix(color, "#000000", 0.32) }
      end

      def counter(x, width, label, value, icon, palette, gold)
        ink, shade = @stage.sky_ink(20)
        @stage.text(label, x: x - 20, y: 18, w: width + 40, align: "center", size: 8, color: ink, shadow: shade && @stage.hard_shadow(8, shade))
        @stage.bitmap(:hud, icon, x + 3, 37, palette.transform_values { @shade }, 3)
        @stage.bitmap(:hud, icon, x, 34, palette, 3)
        @stage.text(value, x: x + 30, y: 34, size: 24, color: gold ? "#FFD54A" : "#FFFFFF", shadow: @stage.hard_shadow(24, @shade))
      end
    end
  end
end
