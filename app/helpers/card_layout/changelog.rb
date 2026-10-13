module CardLayout
  # The Changelog card, 1200x630: the week as release notes. A slim rail on the
  # left holds who, the week's strip, four numbers and the line counts; the
  # entries take the rest, one row per day with work. A port of
  # doc/week_cards/mocks/changelog.dc.html, whose renderVals is the spec.
  class Changelog
    L = 60
    R = 1140
    COL_R = 314 # the rail's right edge
    X_DAY = 360 # the entries' day and tag column
    X_HEAD = 452 # the entries' words
    HEAD_B = 60 # the baseline the name and the entries' header share
    LIST_TOP = 74
    FOOT_RULE = 538
    FOOT_B = 590
    PALETTES = {
      "light" => { bg: "#F8F7F3", ink: "#14171A", muted: "#62665F", faint: "#8A8E86", rule: "#E4E3DC", rule_strong: "#CDCBC1",
                   cell_line: "#C3C1B6", accent: "#00875A", on_accent: "#FFFFFF", avatar_ring: "#D9D7CE" },
      "dark" => { bg: "#0E1012", ink: "#ECEEEF", muted: "#8E959A", faint: "#6B7378", rule: "#22272B", rule_strong: "#394046",
                  cell_line: "#454D54", accent: "#00BA7C", on_accent: "#0E1012", avatar_ring: "#2A3035" }
    }.freeze
    # The strip's four strengths: the accent mixed into the ground.
    LEVELS = { "light" => [ 0.22, 0.44, 0.7, 1 ], "dark" => [ 0.34, 0.54, 0.76, 1 ] }.freeze
    # Each layer's paint, in drawing order.
    LAYERS = {
      wash: { fill: :wash }, rules: { stroke: :rule }, rules_strong: { stroke: :rule_strong },
      cell_empty: { stroke: :cell_line }, cell_post: { stroke: :accent, width: 1.5 }, cell1: { fill: :lvl1 },
      cell2: { fill: :lvl2 }, cell3: { fill: :lvl3 }, cell4: { fill: :lvl4 }, pills: { fill: :ink, opacity: :pill_a },
      tag_ship: { fill: :accent }, tag_pub: { stroke: :accent }, tag_built: { stroke: :rule_strong }, chip: { stroke: :rule_strong }
    }.freeze
    LINK_S = 13.5
    LINK_LS = -0.005
    GOAL_LS = -0.01
    # The Openstage mark, from public/favicon.svg, filled even-odd so the bars show the ground.
    MARK = "M112 0H400A112 112 0 0 1 512 112V400A112 112 0 0 1 400 512H112A112 112 0 0 1 0 400V112A112 112 0 0 1 112 0Z" \
           "M144 288H176A16 16 0 0 1 192 304V368A16 16 0 0 1 176 384H144A16 16 0 0 1 128 368V304A16 16 0 0 1 144 288Z" \
           "M240 224H272A16 16 0 0 1 288 240V368A16 16 0 0 1 272 384H240A16 16 0 0 1 224 368V240A16 16 0 0 1 240 224Z" \
           "M336 144H368A16 16 0 0 1 384 160V368A16 16 0 0 1 368 384H336A16 16 0 0 1 320 368V160A16 16 0 0 1 336 144Z".freeze

    # A day as the card sees it. words are the builder's (or what was logged),
    # empty for a day the card can only count; projects are [name, commits,
    # slot], busiest first.
    Day = Data.define(:date, :projects, :total, :words, :kind, :active) do
      def named?
        words.present?
      end

      def dow
        date.strftime("%a").upcase
      end
    end

    attr_reader :card, :palette, :canvas, :days, :avatar

    def self.palette(theme)
      dark = theme == "dark"
      base = PALETTES.fetch(dark ? "dark" : "light")
      levels = LEVELS.fetch(dark ? "dark" : "light").each_with_index.to_h { |share, i| [ :"lvl#{i + 1}", mix(base[:bg], base[:accent], share) ] }
      base.merge(levels, wash: dark ? mix(base[:bg], base[:accent], 0.13) : "#E1F0E8", pill_a: dark ? 0.1 : 0.065,
                         pill_text: mix(base[:muted], base[:ink], 0.25))
    end

    def self.mix(from, to, share)
      from, to = [ from, to ].map { |hex| hex.delete("#").scan(/../).map { |pair| pair.to_i(16) } }
      "##{from.zip(to).map { |a, b| format('%02X', (a + ((b - a) * share)).round) }.join}"
    end

    def initialize(card)
      @card = card
      @palette = self.class.palette(card.week_card.theme)
      @canvas = Canvas.new(LAYERS.keys)
      @days = card.days.map { |day| day_of(day) }
      draw
    end

    def shows?(section)
      card.week_card.shows?(section)
    end

    private

    def draw
      identity = Identity.new(self)
      @avatar = identity.avatar
      header
      Rail.new(self).draw(identity.bottom)
      rows = Entries.new(self).draw
      footer(rows)
    end

    def day_of(day)
      words = shows?("headlines") && day.headline && day.headline.source != :count ? clean(day.headline.text) : ""
      projects = day.segments.sort_by { |segment| [ -segment.n, segment.project.to_s ] }.map { |segment| [ segment.project, segment.n, segment.slot ] }
      kind = day.headline&.kind || (day.total.positive? ? "built" : nil)
      Day.new(date: day.date, projects: projects, total: day.total, words: words, kind: kind,
              active: day.active || words.present?)
    end

    # The builder's words as the card prints them: no emoji, and a typeset
    # apostrophe inside a word.
    def clean(text)
      CardText.clean(text).gsub(/(\w)'(\w)/, "\\1’\\2")
    end

    # "CHANGELOG · 2026.41" (the year of the ISO week, so 2026-W53 stays 2026),
    # the week and its dates, and the builder's page at the right.
    def header
      start = card.week_card.week_start
      tag_end = canvas.put("CHANGELOG · #{start.cwyear}.#{format('%02d', start.cweek)}", :dm_mono_medium, 10.5, X_DAY, HEAD_B,
                           palette[:accent], spacing: 0.14)
      canvas.put("#{card.label} · #{card.dates}", :inter_medium, 14, tag_end + 18, HEAD_B, palette[:ink], spacing: -0.005)
      canvas.draw(:rules_strong, Shapes.rule(X_DAY, R, LIST_TOP - 1))
      link
    end

    def link
      handle = card.user.username.to_s
      start = canvas.put_end(handle, :inter_medium, LINK_S, R, HEAD_B, palette[:ink], spacing: LINK_LS)
      start = canvas.put_end("openstage.dev/", :inter_medium, LINK_S, start - (LINK_LS * LINK_S), HEAD_B, palette[:muted],
                             spacing: LINK_LS)
      canvas.icon((start - 8 - 14).round, (HEAD_B - (Type.cap(:inter_medium, LINK_S) / 2) - 7).round, 14, "0 0 512 512", MARK,
                  palette[:muted])
    end

    # Next week's goal, larger on a thin week.
    def footer(rows)
      goal = card.week_card.next_goal.to_s
      return unless shows?("goal") && goal.present?

      canvas.draw(:rules, Shapes.rule(L, R, FOOT_RULE))
      canvas.put("UP NEXT", :dm_mono_medium, 10.5, L, FOOT_B, palette[:accent], spacing: 0.16)
      goal = clean(goal)
      room = R - X_DAY
      size = Type.fit([ 18, [ rows <= 3 ? 34 : 26, room / Type.width(goal, :inter_semibold, 1, GOAL_LS) ].min ].max)
      canvas.put(Type.cut_words(goal, :inter_semibold, size, GOAL_LS, room), :inter_semibold, size, X_DAY, FOOT_B,
                 palette[:ink], spacing: GOAL_LS)
    end
  end
end
