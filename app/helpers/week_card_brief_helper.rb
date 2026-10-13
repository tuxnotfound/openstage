# The Weekly Brief, the default week card, 1200x630: the week as an editorial
# memo. A masthead; the lead set large with a byline; the days as a dated list
# with each day's commits; the week's numbers in a rail; next week's goal and
# the link. Every line break and position is computed here with CardText, and
# brief_card returns them as a list the partial draws as is.
module WeekCardBriefHelper
  BRIEF_THEMES = {
    "light" => { paper: "#F7F5F0", ink: "#16140F", ink2: "#47433C", muted: "#736D63", generated: "#736D63", rule: "#DDD8CE",
                 track: "#ECE8DF", accent: "#C4400E", bar: "#5E594F", ring: "rgba(22,20,15,0.14)" },
    # Generated lines recede a little less on dark paper, where thin grey type fades first.
    "dark" => { paper: "#131210", ink: "#EFEBE3", ink2: "#C9C3B8", muted: "#99938A", generated: "#A7A198", rule: "#302D28",
                track: "#211F1C", accent: "#FF7A4C", bar: "#8A8479", ring: "rgba(255,255,255,0.14)" }
  }.freeze
  # The grid: the main column, the rail beside it, and the rules across both.
  LEFT = 60
  RIGHT = 1140
  MAIN_RIGHT = 852
  RAIL_RULE = 882
  RAIL_LEFT = 912
  MASTHEAD = 44
  MASTHEAD_RULE = 60
  FLY = 90
  FOOTER_RULE = 558
  FOOTER = 594
  AVATAR = 34
  # Newsreader's cap height, descender and x-height, and Inter's cap height, in ems.
  SERIF_CAP = 0.715
  SERIF_DESCENT = 0.233
  SERIF_X_HEIGHT = 0.512
  SANS_CAP = 0.728
  # The day list: weekday, numeral, the builder's words, then each day's count
  # and bar under a COMMITS head.
  TEXT_X = 144
  COUNT_RIGHT = 744
  BAR_X = 754
  BAR_MAX = MAIN_RIGHT - BAR_X
  # The numeral column ends 8px past the widest weekday plus two digits, so
  # "WED 30" never touches.
  DATE_RIGHT = (LEFT + %w[MON TUE WED THU FRI SAT SUN].map { |day| CardText.width(day, size: 10.5, face: :inter_semibold, spacing: 1.26) - 1.26 }.max +
                8 + CardText.width("00", size: 18, face: :newsreader_text)).ceil

  include Fit
  include Byline
  include Days
  include Rail

  def brief_card(card)
    brief = brief_context(card)
    fit = brief_fit(brief)
    out = { texts: [], marks: [], icons: [], paths: Hash.new { |paths, layer| paths[layer] = [] }, theme: brief[:t] }
    brief_masthead(out, brief)
    brief_lead(out, brief, fit[:lead])
    brief_byline(out, brief, fit[:lead][:av_top]) if brief[:byline]
    brief_days(out, brief, fit)
    brief_rail(out, brief)
    brief_footer(out, brief)
    out
  end

  def brief_context(card)
    max_day = [ card.days.map(&:total).max.to_i, 1 ].max
    text_right = COUNT_RIGHT - card_text_width(max_day.to_s, :inter_figures, 13) - 22
    { card: card, wc: card.week_card, t: BRIEF_THEMES.fetch(card.week_card.theme, BRIEF_THEMES["light"]),
      rows: brief_rows(card), measure: text_right - TEXT_X, bar_scale: [ max_day, 10 ].max, byline: brief_byline?(card) }
  end

  # Every day of the week, or with the "active" layout only the days with
  # something to say.
  def brief_rows(card)
    days = card.days
    said = days.select { |day| day.active || day.headline }
    days = said if card.week_card.layout == "active" && said.any?
    days.map { |day| brief_row(card, day) }
  end

  # A day is in the builder's words, generated (commits but no words, so the
  # split by project stands in), or quiet.
  def brief_row(card, day)
    headline = card.week_card.shows?("headlines") ? day.headline : nil
    words = headline && headline.source != :count ? CardText.clean(headline.text) : ""
    text = words.presence || brief_stand_in(headline, day)
    kind = if text then :worded elsif day.total.positive? then :generated else :quiet end
    chips = card.week_card.shows?("projects") ? day.segments.sort_by.with_index { |segment, i| [ -segment.n, i ] } : []
    { day: day, kind: kind, text: text, generated: words.empty?, lead: card.lead.date == day.date,
      tag: (headline.kind if text && %w[shipped published].include?(headline&.kind)),
      chips: chips.map { |segment| { name: segment.project, n: segment.n, slot: segment.slot } } }
  end

  # Words that were only emoji: a launch or a post still says what it was.
  def brief_stand_in(headline, day)
    return if headline.nil? || headline.source == :count
    return headline.kind.capitalize if %w[shipped published].include?(headline.kind)

    "Built" unless day.total.positive?
  end

  def brief_masthead(out, brief)
    t = brief[:t]
    brief_text(out, "WEEKLY BRIEF", :inter_bold, 11, LEFT, MASTHEAD, t[:ink], spacing: 0.16)
    brief_text(out, "· #{brief[:card].dates}", :inter_medium, 13, RIGHT, MASTHEAD, t[:ink2], anchor: :end)
    week_right = RIGHT - card_text_width(" · #{brief[:card].dates}", :inter_medium, 13)
    brief_text(out, brief[:card].label, :inter_semibold, 13, week_right, MASTHEAD, t[:ink], anchor: :end)
    brief_hline(out, LEFT, RIGHT, MASTHEAD_RULE, :strong)
  end

  # The fly title says what the lead is; the lead hangs 2% of its size left,
  # so its first stem lines up with the column.
  def brief_lead(out, brief, plan)
    brief_text(out, brief[:card].lead.fly.upcase, :inter_bold, 10.5, LEFT, FLY, brief[:t][:accent], spacing: 0.14)
    plan[:lines].each_with_index do |line, i|
      brief_text(out, line, :newsreader_display, plan[:size], LEFT - (0.02 * plan[:size]), plan[:first] + (i * plan[:step]),
                 brief[:t][:ink], spacing: plan[:spacing])
    end
  end

  # A piece of text at its baseline, measured, so a check can find its edges.
  def brief_text(out, text, face, size, x, baseline, fill, spacing: 0, anchor: :start)
    size = size.round(2)
    out[:texts] << { text: text, face: face, size: size, x: x.round(1), y: baseline.round(1), fill: fill, anchor: anchor,
                     spacing: (spacing * size).round(3), width: card_text_width(text, face, size, spacing) }
  end

  def brief_hline(out, from, to, y, layer = :hair)
    out[:paths][layer] << "M#{brief_number(from)} #{y.round + 0.5}H#{brief_number(to)}"
  end

  def brief_round_rect(x, y, width, height, radius)
    r = [ radius, width / 2.0, height / 2.0 ].min
    arc = "A#{brief_number(r)} #{brief_number(r)} 0 0 1"
    "M#{brief_number(x + r)} #{brief_number(y)}H#{brief_number(x + width - r)}#{arc} #{brief_number(x + width)} #{brief_number(y + r)}" \
      "V#{brief_number(y + height - r)}#{arc} #{brief_number(x + width - r)} #{brief_number(y + height)}H#{brief_number(x + r)}" \
      "#{arc} #{brief_number(x)} #{brief_number(y + height - r)}V#{brief_number(y + r)}#{arc} #{brief_number(x + r)} #{brief_number(y)}Z"
  end

  # 12 or 12.5, never 12.0.
  def brief_number(value)
    rounded = value.round(1)
    rounded == rounded.to_i ? rounded.to_i.to_s : rounded.to_s
  end

  def brief_cap(face, size)
    (CardText::FACES.fetch(face)[:family] == "Newsreader" ? SERIF_CAP : SANS_CAP) * size
  end
end
