module ProgressChart
  # The words of a Compare chart: what it shows, for screen readers; the note
  # under it, which names each number's line style and gives each one's peak
  # when the chart compares numbers, and says which numbers drawn have no
  # line; and its amounts, as the tooltip, the axis and the note write them.
  class CompareNote
    # A number's line by its place in the line order.
    STYLES = %w[solid dotted dashed].freeze

    def initialize(chart)
      @chart = chart
    end

    # The line styles named by the numbers' places among those drawn.
    def note
      return empty if chart.numbers.empty?
      return "#{before}#{styles}#{after}" if chart.indexed?

      "#{one}#{rest}".strip
    end

    # The note around the line styles' names, so the browser can name them by
    # its own line order; nil unless the chart compares numbers.
    def note_parts
      [ before, after ] if chart.indexed?
    end

    def aria_label
      return "Nothing to chart, #{labels.words}" if chart.numbers.empty?

      named = sentence((chart.lined.presence || chart.numbers).map(&:word))
      what = chart.average? ? "7-day average of #{named} per day" : "#{named.upcase_first} per #{labels.unit_word}"
      "#{what} by #{chart.per}, #{'each against its own peak, ' if chart.indexed?}#{labels.words}"
    end

    # A tooltip's words for a point where no project has anything.
    def none
      "Nothing this #{labels.unit_word}"
    end

    # A value as the tooltip and the note write it: to a tenth when averaged.
    def amount(number, value)
      text = chart.average? ? format("%.1f", value) : ActiveSupport::NumberHelper.number_to_delimited(value.round)
      "#{'$' if number&.money?}#{text}"
    end

    # A gridline's value, a whole count or a step such as 0.5.
    def tick(number, value)
      "#{'$' if number&.money?}#{value.is_a?(Integer) ? ActiveSupport::NumberHelper.number_to_delimited(value) : value.to_f}"
    end

    private

    attr_reader :chart

    def labels
      chart.window.labels
    end

    def before
      chart.average? ? "7-day averages. " : ""
    end

    def styles
      sentence(chart.lined.each_with_index.map { |number, i| "#{i.zero? ? number.label : number.word} #{STYLES.fetch(chart.numbers.index(number))}" })
    end

    def after
      ", each against its own peak in the window; 100% is #{sentence(chart.lined.map { |number| peak_words(number) })}.#{rest}"
    end

    def peak_words(number)
      text = amount(number, chart.peak(number))
      "#{text} #{number.word_after(text)}#{" a #{labels.unit_word}" unless number.level?}"
    end

    def one
      number = chart.lined.first
      return "" unless number

      per_line = chart.lone ? "" : ", one line per #{chart.per}"
      chart.average? ? "A 7-day average of #{number.word} per day#{per_line}." : "#{number.label} per #{labels.unit_word}#{per_line}."
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

    def empty
      chart.lone ? "This project shows no numbers yet." : "No #{chart.per} here shows a number yet."
    end

    def sentence(words, last = "and")
      words.to_sentence(two_words_connector: " #{last} ", last_word_connector: " #{last} ")
    end
  end
end
