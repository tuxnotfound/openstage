module CardLayout
  # The Pixel Stage card, 1200x630: the week as an 8-bit level. Every commit is
  # a block in its day's tower, every launch a flag, every post a broadcast
  # mast, every rest day a campfire. The builder is the player, and a stage
  # door leads to next week. Everything sits on a 4px grid. A port of
  # doc/week_cards/mocks/pixel_stage.dc.html: its scene generator runs here in
  # the same order, with the same seeded random numbers.
  class PixelStage
    P = 4
    GY = 520 # the grass line
    # The layers, from the back. Each holds one path per colour and opacity.
    STAGES = %i[sky dith deco far_hills sun_layer hills glow ground gate props t_base t_hi t_lo fx_glow fx
                hero_back hero box_shadow box_outer box_mid box_inner tails hud strip].freeze
    OTHER = "#8C92B0".freeze
    # Ascent and descent, in ems, of the font that sets each face's lines.
    METRICS = { press_start: [ 1.0, 0.0 ], pixelify_medium: [ 0.92, 0.28 ], pixelify_semibold: [ 0.92, 0.28 ] }.freeze
    # face: :press_start or :pixelify_medium or :pixelify_semibold. align: the
    # box is x to x + w. shadow: [offset, colour], a hard drop shadow.
    Text = Data.define(:text, :x, :y, :w, :align, :size, :lh, :face, :color, :shadow)
    # A day as the level sees it. counts: commits by project, busiest first.
    Day = Struct.new(:index, :date, :label, :counts, :total, :cx, :zx, :kind, :text, :auto, :box, :units, :cols, :rows, :k, :tw,
                     :heights, :mirror, :top, :left, :pole, :mast, :player, :pennant, :target, :tail, keyword_init: true) do
      def shipped? = kind == "shipped"
      def posted? = kind == "published"
      def has? = text.present?
      def rest? = total.zero? && !has?
    end

    attr_reader :card, :dark, :days, :projects, :random, :texts, :obstacles, :sky, :ground, :kind, :hero_day, :fire_day, :pose
    # How many commits a block stands for, once the towers are laid out.
    attr_accessor :per

    include Grid

    def initialize(card)
      @card = card
      @dark = card.week_card.theme != "light"
      @stages = STAGES.index_with { {} }
      @texts = []
      @obstacles = []
      @random = Random.new(card.user.username.to_s, card.week_card.week_start)
      setup
      draw
    end

    # Each layer's paths, in drawing order: [d, fill, opacity].
    def layers
      @stages.values.flat_map { |paths| paths.map { |(fill, opacity), d| [ d, fill, opacity ] } }
    end

    # Where a text's baseline falls, as Chrome sets the mock's HTML: the line's
    # font's ascent and descent rounded to whole pixels, and the spare height
    # split with the odd pixel below. Tiny5 holds only the digits and no space,
    # so Pixelify Sans sets the lines of the faces that use both.
    def baseline(text)
      ascent, descent = METRICS.fetch(text.face).map { |metric| (metric * text.size).round }
      text.y + ascent + ((text.lh - ascent - descent) / 2.0).floor
    end

    # The x a text is anchored at in SVG, and how.
    def anchor(text)
      case text.align
      when "center" then [ text.x + (text.w / 2.0), "middle" ]
      when "right" then [ text.x + text.w, "end" ]
      else [ text.x, "start" ]
      end
    end

    def shows?(section)
      card.week_card.shows?(section)
    end

    def put(stage, fill, d, opacity = 1)
      return if d.blank?

      (@stages.fetch(stage)[[ fill, opacity ]] ||= +"") << d
    end

    def text(text, x:, y:, size:, w: 600, align: "left", lh: nil, face: :press_start, color: "#FFFFFF", shadow: nil)
      @texts << Text.new(text: text, x: x, y: y, w: w, align: align, size: size, lh: lh || size, face: face, color: color, shadow: shadow)
    end

    # A hard drop shadow an eighth of the size away, at least a pixel.
    def hard_shadow(size, color)
      [ [ 1, size / 8.0 ].max, color ]
    end

    def wide(text, size)
      CardText.width(text, size: size, face: :press_start)
    end

    def pixelify(text, size, weight = 500)
      CardText.width(text, size: size, face: weight >= 600 ? :pixelify_semibold : :pixelify_medium)
    end

    def block(x, y, w, h, margin = 0)
      @obstacles << { x: x - margin, y: y - margin, w: w + (2 * margin), h: h + (2 * margin) }
    end

    def hit?(box)
      @obstacles.any? { |o| box[:x] < o[:x] + o[:w] && box[:x] + box[:w] > o[:x] && box[:y] < o[:y] + o[:h] && box[:y] + box[:h] > o[:y] }
    end

    # The colour of a project's blocks, by its rank in the week, whether or
    # not the key names the projects. Past six, the smallest merge into "other".
    def color_of(name)
      index = projects.index { |project, _n| project == merged(name) }
      index && merged(name) != "other" ? WeekCardsHelper::PROJECT_COLORS.fetch(index, OTHER) : OTHER
    end

    def merged(name)
      @merged.include?(name) ? "other" : name
    end

    def rank(name)
      projects.index { |project, _n| project == merged(name) } || 99
    end

    def thin?
      @thin
    end

    # Small weeks zoom in: bigger blocks, and rest props and masts on 8px cells.
    def block_size
      @block_size
    end

    def cell2
      thin? ? 2 * P : P
    end

    # Small text on the sky takes the ink that reads better on the band behind it.
    def sky_ink(y, light = "#FFE7C2")
      return [ light, "#000000" ] if dark

      band = sky[:bands][(y / 44).clamp(0, sky[:bands].size - 1)]
      Paint.contrast("#1B1F3B", band) > Paint.contrast("#FFFFFF", band) ? [ "#1B1F3B", nil ] : [ "#FFFFFF", "#1B1F3B" ]
    end

    private

    def setup
      @kind = sky_kind(card.totals.peak_hour || 21)
      @sky = Palettes::SKIES.fetch(dark ? "dark" : "light").fetch(@kind)
      @ground = Palettes::GROUND.fetch(@sky[:ground].to_sym)
      setup_projects
      @days = card.days.each_with_index.map { |day, i| day_of(day, i) }
      busiest = @days.map(&:total).max || 0
      @thin = busiest <= 6
      @block_size = { 6 => 40, 15 => 32 }.find { |most, _size| busiest <= most }&.last || 24
      setup_pose
    end

    # The sky's palette comes from the hour the builder commits most.
    def sky_kind(hour)
      return :night if hour >= 21 || hour < 5
      return :dusk if hour >= 17

      hour >= 11 ? :day : :dawn
    end

    # On the week's biggest launch (by that day's commits); else by the last
    # fire; else at the stage door.
    def setup_pose
      @hero_day = @days.select(&:shipped?).inject(nil) { |hero, day| hero.nil? || day.total >= hero.total ? day : hero }
      rests = @days.select(&:rest?)
      @pose = if @hero_day then :stand
      elsif rests.any? then :sit
      else :idle
      end
      @fire_day = rests.last if @pose == :sit
    end

    def setup_projects
      all = card.projects.select(&:shown).map { |project| [ project.name.to_s, project.n ] }
      @merged = all.size > 6 ? all.drop(5).map(&:first).to_set : Set.new
      @projects = all.size > 6 ? all.first(5) + [ [ "other", all.drop(5).sum(&:last) ] ] : all
    end

    def day_of(day, index)
      words = shows?("headlines") && day.headline && day.headline.source != :count
      Day.new(index: index, date: day.date, label: "#{day.date.strftime('%a').upcase} #{day.date.day}",
              counts: day.segments.to_h { |segment| [ segment.project.to_s, segment.n ] }, total: day.total, cx: snap(93 + (150 * index)),
              zx: 18 + (150 * index), kind: day.headline&.kind, text: day.headline ? CardText.clean(day.headline.text) : nil,
              auto: !words)
    end

    def draw
      Scenery.new(self).draw
      Towers.new(self).draw
      Props.new(self).draw
      Player.new(self).draw
      Fireworks.new(self).draw
      Callouts.new(self).draw
      Hud.new(self).draw
    end
  end
end
