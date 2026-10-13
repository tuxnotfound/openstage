module CardLayout
  # The Star Chart card, 1200x630: the whole week under one sky. On the
  # right, a disc with a ring per day (Monday inside) and the hours clockwise
  # from midnight at the top: a star for every hour with commits, a nova for a
  # launch, a comet for a post, and the dust of earlier commits. On the left,
  # the persona the week earns, every day as a row, the projects, and next
  # week's goal. A port of doc/week_cards/mocks/star_chart.dc.html.
  class StarChart
    LEFT = 48
    WIDTH = 522
    GUTTER = 66
    GLYPH = 20
    HEAD_X = GUTTER + GLYPH
    HEAD_W = WIDTH - HEAD_X
    FOOT_TOP = 576
    # The disc: its centre, rims, hub and avatar.
    C = { x: 880, y: 290, r: 240, r2: 234, hub: 46, avatar: 84 }.freeze
    # Inside the disc the sky keeps one palette in both themes.
    SKY = {
      ring_on: "rgba(200,212,255,0.25)", ring_off: "rgba(200,212,255,0.14)", horizon: "rgba(200,212,255,0.4)",
      rim_in: "rgba(200,212,255,0.45)", tag_day: "#D6DCF6", tag_off: "#7882AE", dust: "rgba(214,224,255,0.5)", milky: "#7E92FF",
      milky_o: 0.55, halo_o: 0.85, center: "#FFFFFF", nova: "#FFF5DA", nova_glow: "#FFCF6E", nova_name: "#FFE7B0",
      comet: "#E8EEFF", comet_dust: "#B9C6FF", night: "#0A0F29", night_o: 0.6, knock: "#0A0E26", dusk: "#3A4FAA",
      day: "#6F88E6", day_r: 440
    }.freeze
    PALETTES = {
      "dark" => {
        g0: "#0C1330", g1: "#05070F", grain_ink: 1, grain_o: 0.07, aura: "#2F44C4", aura_o: 0.42, disc0: "#141D45",
        disc1: "#070B1C", hub: "#060914", hub_ring: "rgba(200,212,255,0.45)", rim_out: "rgba(200,212,255,0.5)",
        tick: "rgba(200,212,255,0.4)", tick_major: "rgba(226,232,255,0.9)", hour: "#B9C1E0", key_text: "#AAB2D2",
        key_icon: "#C9D2F5", title: "#F2ECDF", text: "#F2ECDF", muted: "#9AA3C4", faint: "#6C759A", gold: "#E2BC6A",
        pub: "#AFC0FF", auto: "#9AA3C4", num: "#D5DAEE", sub_name: "#AEB6D4", hair: "rgba(154,163,196,0.16)",
        rule: "rgba(154,163,196,0.34)", pro_line: "rgba(226,188,106,0.6)", moon: "#E9ECF8", moon_glow: "#AFC0FF",
        sun: "#F2CB74", sun_glow: "#FFCF6E", lum_o: 0.7, earth_o: 0.14, glow_ink: "#FFD696", glow_o: 0.26,
        dusk_o: 0.18, day_o: 0.3, star_hue: "#DCE5FF", star_center: "#FFFFFF", star_glow_o: 0.7
      },
      "light" => {
        g0: "#F7F2E6", g1: "#EFE7D4", grain_ink: 0.12, grain_o: 0.10, aura: "#0B1230", aura_o: 0.16, disc0: "#1B2650",
        disc1: "#0B1230", hub: "#F4EEE1", hub_ring: "rgba(30,43,71,0.6)", rim_out: "rgba(30,43,71,0.6)",
        tick: "rgba(30,43,71,0.45)", tick_major: "rgba(30,43,71,0.9)", hour: "#34405D", key_text: "#4A5470",
        key_icon: "#34405D", title: "#1E2B47", text: "#1E2B47", muted: "#5E6680", faint: "#8A8F9F", gold: "#946500",
        pub: "#3B57B8", auto: "#5E6680", num: "#1E2B47", sub_name: "#4A5470", hair: "rgba(30,43,71,0.12)",
        rule: "rgba(30,43,71,0.26)", pro_line: "rgba(148,101,0,0.55)", moon: "#2E3A5C", moon_glow: "#2E3A5C",
        sun: "#946500", sun_glow: "#946500", lum_o: 0, earth_o: 0.1, glow_ink: "#1E2B47", glow_o: 0,
        dusk_o: 0.14, day_o: 0.24, star_hue: "#3B4A78", star_center: "#E8EEFF", star_glow_o: 0.25
      }
    }.freeze
    LAYERS = { rules: { stroke: :rule }, hairs: { stroke: :hair }, chip: { stroke: :pro_line } }.freeze
    # The glyphs a row and the key use, on a 24px grid.
    STAR = "M12 2.5l2.3 7.2 7.2 2.3-7.2 2.3L12 21.5l-2.3-7.2L2.5 12l7.2-2.3z".freeze
    DOT = "M12 12m-3.6 0a3.6 3.6 0 1 0 7.2 0a3.6 3.6 0 1 0 -7.2 0".freeze
    COMET_HEAD = "M12.2 8.2a3.8 3.8 0 1 0 7.6 0a3.8 3.8 0 1 0 -7.6 0Z".freeze
    COMET_TAIL = "M18.4 10.6L2.6 21.4L13.6 5.6Z".freeze

    # A day as the chart sees it. projects: [name, commits], busiest first.
    # title: the builder's words, or what was logged; empty when the card
    # writes the day itself. launch and post: logged times, in hours.
    Day = Data.define(:index, :date, :hours, :projects, :kind, :title, :launch, :post) do
      def commits
        projects.sum(&:last)
      end

      def active?
        commits.positive? || kind.present?
      end

      def label
        "#{date.strftime('%a').upcase} #{date.day}"
      end
    end

    attr_reader :card, :palette, :dark, :canvas, :days, :hues, :persona, :avatar, :title, :sky, :stars, :day_labels, :key, :legend, :arrow

    # DM Sans and DM Mono set their baseline 0.99em below the top of a 1.3em
    # content box, so in a line box this high it sits here.
    def self.base_in(box, size)
      ((box - (1.3 * size)) / 2) + (0.99 * size)
    end

    # Only for what the builder did not write (repo names, a handle): cut
    # with an ellipsis, never after a separator. The block measures.
    def self.cut(text, room)
      return text if yield(text) <= room

      k = text.length
      k -= 1 while k > 1 && yield("#{text[0, k].sub(/[\s\-_.]+\z/, '')}…") > room
      "#{text[0, k].sub(/[\s\-_.]+\z/, '')}…"
    end

    # The last resort for a word longer than the line: break it anywhere.
    def self.hard_wrap(text, room)
      text.each_char.with_object([ +"" ]) do |char, lines|
        if lines.last.present? && yield(lines.last + char) > room then lines << (char.strip.empty? ? +"" : +char)
        else lines.last << char
        end
      end.reject(&:empty?)
    end

    # One decimal, as the sky's path data is written.
    def self.f1(value)
      rounded = (value * 10).round / 10.0
      rounded == rounded.to_i ? rounded.to_i.to_s : rounded.to_s
    end

    # A full circle as path data, so many can share one path.
    def self.circle(x, y, r)
      "M#{f1(x - r)} #{f1(y)}a#{f1(r)} #{f1(r)} 0 1 0 #{f1(2 * r)} 0a#{f1(r)} #{f1(r)} 0 1 0 #{f1(-2 * r)} 0Z"
    end

    def initialize(card)
      @card = card
      @dark = card.week_card.theme != "light"
      @palette = PALETTES.fetch(dark ? "dark" : "light")
      @canvas = Canvas.new(LAYERS.keys)
      @days = card.days.each_with_index.map { |day, i| day_of(day, i) }
      @hues = shows?("projects") ? projects.map { |project| Colors.tones(project_color(project)) } : []
      draw
    end

    def shows?(section)
      card.week_card.shows?(section)
    end

    # A builder without a picture shows their initials at the pole instead:
    # the first and last names' first letters. Turned off, a gold star.
    def initials
      return unless shows?("avatar") && card.user.avatar_url.blank?

      words = (card.user.display_name.presence || card.user.username).to_s.split
      [ words.first, words.size > 1 ? words.last : nil ].compact.map { |word| word[0] }.join.upcase
    end

    # The week's projects with commits, busiest first.
    def projects
      @projects ||= card.projects.select(&:shown)
    end

    def commits
      card.totals.commits
    end

    # A project's three tones (halo, core, a dot for paper), or white when the
    # card shows no project colours.
    def tones(name)
      hues[projects.index { |project| project.name == name } || -1] || [ "#FFFFFF", "#FFFFFF", "#888888" ]
    end

    def slot(name)
      (projects.index { |project| project.name == name } || 0).clamp(0, Stars::SLOTS - 1)
    end

    def dot_color(name)
      tones(name)[dark ? 0 : 2]
    end

    def ring(index)
      71 + (25 * index)
    end

    # A point on the disc at a radius and an hour, midnight at the top.
    def at(radius, hour)
      angle = (hour / 24.0 * Math::PI * 2) - (Math::PI / 2)
      [ C[:x] + (radius * Math.cos(angle)), C[:y] + (radius * Math.sin(angle)) ]
    end

    private

    # The left column first, since the persona picks the sky's lit window:
    # the heading, the goal and footer, then the rows in the room between,
    # then the totals under them. The sky, its day names and the key after.
    def draw
      @avatar = { x: C[:x] - (C[:avatar] / 2), y: C[:y] - (C[:avatar] / 2), size: C[:avatar], url: card.user.avatar_url } if avatar?
      heading = Heading.new(self)
      @persona = heading.persona
      @title = heading.title
      @legend = Legend.new(self)
      foot = Foot.new(self)
      goal_top = foot.draw
      @arrow = foot.arrow
      legend.draw(Rows.new(self).draw(heading.list_top, goal_top - 14 - legend.height))
      @stars = Stars.new(self)
      @sky = Sky.new(self, persona.hours)
      @day_labels = DayLabels.new(self)
      @key = Key.new(self)
    end

    def avatar?
      shows?("avatar") && card.user.avatar_url.present?
    end


    def day_of(day, index)
      words = shows?("headlines") && day.headline && day.headline.source != :count ? CardText.clean(day.headline.text) : ""
      projects = day.segments.sort_by { |segment| -segment.n }.map { |segment| [ segment.project.to_s, segment.n ] }
      Day.new(index: index, date: day.date, hours: day.hours, projects: projects, kind: day.headline&.kind, title: words,
              launch: hour_of(day.launches.first), post: hour_of(day.posts.first))
    end

    def hour_of(log)
      log && (log.at.hour + (log.at.min / 60.0))
    end

    def project_color(project)
      project.slot ? WeekCardsHelper::PROJECT_COLORS.fetch(project.slot, WeekCardsHelper::OTHER_COLOR) : WeekCardsHelper::OTHER_COLOR
    end
  end
end
