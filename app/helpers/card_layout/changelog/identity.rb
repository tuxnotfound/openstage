module CardLayout
  class Changelog
    # Who, at the top of the rail: the avatar, the name, the Pro chip and the
    # GitHub handle. The name never loses a letter while it can wrap.
    class Identity
      AVATAR = 46
      NAME_LS = -0.01
      CHIP = "OPENSTAGE PRO".freeze
      CHIP_S = 8.5
      CHIP_LS = 0.1
      CHIP_H = 15
      CHIP_GAP = 8
      GITHUB = "M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z".freeze

      # avatar: where the picture goes, or nil. bottom: where the identity
      # ends, or nil when it shows nothing.
      attr_reader :avatar, :bottom

      def initialize(layout)
        @layout = layout
        @canvas = layout.canvas
        @palette = layout.palette
        user = layout.card.user
        @avatar = { x: L, y: 39, size: AVATAR, url: user.avatar_url } if layout.shows?("avatar") && user.avatar_url.present?
        @x = @avatar ? L + AVATAR + 14 : L
        draw(user)
      end

      private

      def draw(user)
        @pro = user.pro?
        last_baseline, last_width, size = draw_name((user.display_name.presence || user.username).to_s) if @layout.shows?("name")
        handle = draw_handle("@#{user.github_username}", last_baseline) if @layout.shows?("github") && user.github_username.present?
        @bottom = bottom_of(handle || last_baseline)
        draw_chip(last_baseline, last_width, size, handle) if last_baseline && @pro
      end

      # Just under the handle, else the name, else the avatar.
      def bottom_of(baseline)
        baseline ||= HEAD_B + 19 if @avatar
        baseline + 3 if baseline
      end

      # Returns the last line's baseline and width, and the size.
      def draw_name(name)
        lines, size, @chip_beside = fit_name(name)
        height = (size * 1.2).round
        lines.each_with_index { |line, k| @canvas.put(line, :inter_semibold, size, @x, HEAD_B + (k * height), @palette[:ink], spacing: NAME_LS) }
        [ HEAD_B + ((lines.size - 1) * height), Type.width(lines.last, :inter_semibold, size, NAME_LS), size ]
      end

      # In order: one line beside the chip, 20px down to 15px; one line at 15px
      # or more with the chip moved off it; two balanced lines at 17px down to
      # 15px; two lines at 15px, the second cut at a word.
      def fit_name(name)
        room = COL_R - @x
        unit = Type.width(name, :inter_semibold, 1, NAME_LS)
        beside = Type.fit([ 20, (room - (@pro ? CHIP_GAP + chip_width : 0)) / unit ].min)
        return [ [ name ], beside, @pro ] if beside >= 15

        alone = Type.fit([ 20, room / unit ].min)
        return [ [ name ], alone, false ] if alone >= 15

        lines = Lines.new(name, :inter_semibold, NAME_LS)
        17.step(15, -0.5) do |size|
          balanced = lines.balance(size, room, 2)
          return [ balanced, size, false ] if balanced
        end
        [ cut_name(name, room), 15, false ]
      end

      def cut_name(name, room)
        words = name.split(" ")
        k = 1
        k += 1 while k < words.size && Type.width(words[0..k].join(" "), :inter_semibold, 15, NAME_LS) <= room
        first = Type.cut(words[0...k].join(" "), :inter_semibold, 15, NAME_LS, room)
        k < words.size ? [ first, Type.cut_words(words[k..].join(" "), :inter_semibold, 15, NAME_LS, room) ] : [ first ]
      end

      # GitHub usernames run to 39 characters; a long one steps down to 10px,
      # then is cut. Without the name, the handle takes its place.
      def draw_handle(handle, last_baseline)
        baseline = last_baseline ? last_baseline + 19 : HEAD_B
        room = COL_R - @x - 17
        size = Type.fit([ 10, [ 12.5, room / Type.width(handle, :dm_mono_regular, 1) ].min ].max)
        @handle_mid = baseline - (Type.cap(:dm_mono_regular, size) / 2)
        @canvas.icon(@x, (@handle_mid - 6).round(2), 12, "0 0 16 16", GITHUB, @palette[:muted])
        @handle_end = @canvas.put(Type.cut(handle, :dm_mono_regular, size, 0, room), :dm_mono_regular, size, @x + 17, baseline,
                                  @palette[:muted])
        baseline
      end

      # Beside the name when it fits; else after the handle; else on a line of
      # its own.
      def draw_chip(last_baseline, last_width, size, handle)
        if @chip_beside || @x + last_width + CHIP_GAP + chip_width <= COL_R
          x, mid = @x + last_width + CHIP_GAP, last_baseline - (Type.cap(:inter_semibold, size) / 2)
        elsif handle && @handle_end + 10 + chip_width <= COL_R
          x, mid = @handle_end + 10, @handle_mid
        else
          x, mid = @x, (handle || last_baseline) + 17
          @bottom = mid + (CHIP_H / 2.0)
        end
        chip(x.round, (mid - (CHIP_H / 2.0)).round)
      end

      def chip(x, top)
        @canvas.draw(:chip, Shapes.outline(x, top, chip_width, CHIP_H, 3))
        @canvas.put(CHIP, :dm_mono_medium, CHIP_S, x + ((chip_width - chip_text_width) / 2), top + (CHIP_H / 2.0) +
                    (Type.cap(:dm_mono_medium, CHIP_S) / 2), @palette[:muted], spacing: CHIP_LS)
      end

      def chip_text_width
        Type.width(CHIP, :dm_mono_medium, CHIP_S, CHIP_LS)
      end

      def chip_width
        chip_text_width.ceil + 12
      end
    end
  end
end
