module NumbersHelper
  # A number's change against the window before, as progress_change writes
  # the commits': [arrow, words, up], nils with nothing to compare.
  def number_change(number, section)
    return progress_change(section) if number.key == "commits"
    return [ nil, nil, nil ] unless number.before&.positive?

    change = ((100.0 * number.total / number.before) - 100).round
    return [ nil, "same as the previous #{Progress::WindowLabels::SPANS.fetch(section.labels.range)}", nil ] if change.zero?

    [ change.positive? ? "▲" : "▼", "#{change.abs}% #{section.labels.versus}", change.positive? ]
  end

  # The numbers charted once one is switched: nil for all of them, and the
  # last one on stays on. numbers: a Progress::NumbersService's.
  def numbers_toggled(numbers, key)
    on = numbers.select(&:chart).map(&:key)
    after = on.include?(key) ? on - [ key ] : numbers.map(&:key) & (on + [ key ])
    after = on if after.empty?
    after.size == numbers.size ? nil : after
  end

  # The height each chart takes, smaller once they stack.
  def numbers_chart_height(numbers)
    numbers.count(&:chart) > 1 ? "h-[180px]" : ""
  end
end
