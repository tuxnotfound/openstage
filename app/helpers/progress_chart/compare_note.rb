module ProgressChart
  # The words of a Compare chart: what it shows, for screen readers; the note
  # under it, only when a number drawn has no line, to say why, or nothing
  # is drawn; and its amounts, as the tooltip and the axis write them. The
  # toggles name the numbers and their line styles, and the tooltip gives
  # the real values, so a chart that draws everything asked for has no note.
  class CompareNote
    def initialize(chart)
      @chart = chart
    end

    # Why a number drawn has no line; nil when every one has.
    def note
      return empty if chart.numbers.empty?

      rest.strip.presence
    end

    def aria_label
      return "Nothing to chart, #{labels.words}" if chart.numbers.empty?

      "#{what.upcase_first} by #{chart.per}, #{'each on its own scale, ' if chart.indexed?}#{labels.words}"
    end

    # What a point's title adds on an averaged chart. A level is never
    # averaged, so beside one it names the numbers that are.
    def averaged
      return unless chart.average?

      flows = chart.lined.reject(&:level?)
      " · 7-day average#{" of #{sentence(flows.map(&:word))}" if flows.size < chart.lined.size}"
    end

    # A tooltip's words for a point where no project has anything.
    def none
      "Nothing this #{labels.unit_word}"
    end

    # A value as the tooltip writes it: to a tenth when averaged.
    def amount(number, value)
      return Revenue::Money.write(value, chart.currency) if number&.money?
      return format("%.1f", value) if chart.average? && !number&.level?

      ActiveSupport::NumberHelper.number_to_delimited(value.round)
    end

    # A gridline's value, a whole count or a step such as 0.5.
    def tick(number, value)
      return Revenue::Money.write(value, chart.currency) if number&.money?

      value.is_a?(Integer) ? ActiveSupport::NumberHelper.number_to_delimited(value) : value.to_f.to_s
    end

    private

    attr_reader :chart

    def labels
      chart.window.labels
    end

    # The numbers it draws, per point: an average of the flows, with any level
    # named apart, as it is never averaged.
    def what
      levels, flows = (chart.lined.presence || chart.numbers).partition(&:level?)
      return "#{sentence((levels + flows).map(&:word))} per #{labels.unit_word}" unless chart.average?

      [ sentence(levels.map(&:word)).presence, "7-day average of #{sentence(flows.map(&:word))} per day" ].compact.join(" and ")
    end

    # The numbers drawn with no line, and why.
    def rest
      colorless, quiet, missing = unlined
      [ (" Only projects past the tenth count #{sentence(colorless.map(&:word), 'or')}, and the chart draws ten projects at most." if colorless.any?),
        (" No #{sentence(quiet.map(&:word), 'or')} #{labels.word}." if quiet.any?),
        (" None of the #{chart.per}s in view counts #{sentence(missing.map(&:word), 'or')}." if missing.any?) ].join
    end

    # The numbers drawn with no line, as [counted only by projects past the
    # palette, which have no colour to draw in; with none in the window;
    # counted by no project in view].
    def unlined
      lines = ->(number) { chart.every_line.select { |line| line.number == number } }
      colorless, rest = (chart.numbers - chart.lined).partition { |number| lines.call(number).any? { |line| line.total.positive? } }
      [ colorless, *rest.partition { |number| lines.call(number).any? } ]
    end

    # With nothing drawn, the rows show no number yet: a row shows a number
    # that sits beside another only with that one, which the chart can draw
    # (Progress::Numbers.shown).
    def empty
      chart.lone ? "This project shows no numbers yet." : "No #{chart.per} here shows a number yet."
    end

    def sentence(words, last = "and")
      words.to_sentence(two_words_connector: " #{last} ", last_word_connector: " #{last} ")
    end
  end
end
