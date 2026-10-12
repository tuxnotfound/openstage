# The week card's header lines and the contents of its extras cells. Layout of
# the card as a whole is in WeekCardsHelper.
module WeekCardPartsHelper
  LANGUAGE_COLORS = {
    "Ruby" => "#CC342D", "ERB" => "#E4A11B", "JavaScript" => "#F1E05A", "TypeScript" => "#3178C6",
    "HTML" => "#E34C26", "CSS" => "#663399", "SCSS" => "#C6538C", "Python" => "#3572A5", "Go" => "#00ADD8",
    "Rust" => "#DEA584", "Swift" => "#F05138", "Kotlin" => "#A97BFF", "Java" => "#B07219", "PHP" => "#4F5D95",
    "Elixir" => "#6E4A7E", "Shell" => "#89E051", "Dart" => "#00B4AB", "Vue" => "#41B883", "Svelte" => "#FF3E00",
    "C" => "#555555", "C++" => "#F34B7D", "C#" => "#178600", "SQL" => "#E38C00", "Markdown" => "#083FA1"
  }.freeze

  # "GitHub @tux · building in public since Mar 23 · week 29"
  def card_identity_line(card)
    wc, building = card.week_card, card.extras.building
    parts = []
    parts << "GitHub @#{card.user.github_username}" if wc.shows?("github") && card.user.github_username.present?
    if wc.shows?("building") && building
      since = building.since.year == wc.week_start.year ? building.since.strftime("%b %-d") : building.since.strftime("%b %Y")
      parts << "building in public since #{since} · week #{building.week}"
    end
    parts.join(" · ")
  end

  # "STREAK 1 DAY · BEST RUN THIS WEEK 4 DAYS". A streak only means something
  # in the week it is still running.
  def card_streak_line(card)
    return "" unless card.week_card.shows?("streak")

    parts = []
    parts << "STREAK #{card.streak} #{'day'.pluralize(card.streak).upcase}" if card.streak.to_i.positive?
    parts << "BEST RUN THIS WEEK #{card.best_run} #{'day'.pluralize(card.best_run).upcase}" if card.best_run.positive?
    parts.join(" · ")
  end

  # Twenty-four bars, one per hour, the busiest two hours in full colour.
  def card_hour_bars(hours, left, width, theme)
    gap = 2
    bar = [ (width - (23 * gap)) / 24.0, 7 ].min
    most = [ hours.counts.max, 1 ].max
    peak = [ hours.peak_from, (hours.peak_from + 1) % 24 ]
    hours.counts.each_with_index.map do |count, hour|
      height = [ (count * 34.0 / most).round, 2 ].max
      color = if peak.include?(hour) && count.positive? then theme[:text]
      elsif count.positive? then theme[:muted]
      else theme[:faint]
      end
      { x: (left + (hour * (bar + gap))).round(1), width: bar.round(1), height: height, color: color }
    end
  end

  def card_hour_label(hours)
    format("%02d:00 – %02d:00", hours.peak_from, hours.peak_to)
  end

  # The languages bar's blocks, biggest first, with what the top five leave
  # out as one grey block at the end.
  def card_language_blocks(languages, left, width, theme)
    shares = languages + [ [ nil, [ 100 - languages.sum(&:last), 0 ].max ] ]
    shares = shares.reject { |_name, percent| percent.zero? }
    room = width - (2 * (shares.size - 1))
    x = left.to_f
    shares.map do |name, percent|
      block = { x: x.round(1), width: (room * percent / 100.0).round(1),
                color: name ? LANGUAGE_COLORS.fetch(name, WeekCardsHelper::OTHER_COLOR) : theme[:axis] }
      x += block[:width] + 2
      block
    end
  end

  # "Ruby 46% · TypeScript 26% · ERB 7%", as many as fit.
  def card_language_text(languages, width)
    languages.each_with_object([]) do |(name, percent), kept|
      candidate = (kept + [ "#{name} #{percent}%" ]).join(" · ")
      break kept if CardText.width(candidate, size: 11) > width

      kept << "#{name} #{percent}%"
    end.join(" · ")
  end

  # What GitHub counted this week, each as [number, label], zeros left out.
  def card_repo_items(repos)
    items = []
    items << [ repos.releases.to_s, "release".pluralize(repos.releases) ] if repos.releases.positive?
    items << [ "+#{repos.stars}", "star".pluralize(repos.stars) ] if repos.stars.positive?
    items
  end

  def card_number(number)
    number_with_delimiter(number, delimiter: ",")
  end
end
