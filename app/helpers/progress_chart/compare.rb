module ProgressChart
  # Commits and site visits on one chart, on the section's points: a line per
  # project and number, in the project's colour, commits solid and visits
  # dotted. A week's commits and a week's visits share no scale, so with both
  # in view each number is drawn against its own peak in the window, its
  # projects on one scale so they still compare; the tooltip keeps the real
  # numbers. With one number in view, the axis is that number's. It answers
  # what Trend answers, so the chart partial draws it.
  class Compare
    # metric: "commits" or "visits"; values: real, one per point.
    Line = Data.define(:repo, :name, :rank, :metric, :values) do
      def dashed?
        metric == "visits"
      end

      # Which line a switch hides, before the chart is drawn again.
      def key
        "#{repo}|#{metric}"
      end
    end
    PEAK = 100.0
    WORDS = { "commits" => "commits", "visits" => "site visits" }.freeze

    # trend: the section's Trend; visits: {repo's full name => visits per
    # point}; projects: the section's Progress::Projects; hidden: {repo's full
    # name => the numbers switched off for it}.
    def initialize(trend, visits:, projects:, hidden: {})
      @trend = trend
      @visits = visits
      @projects = projects
      @hidden = hidden
    end

    def lines
      @lines ||= commit_lines + visit_lines
    end

    # Both numbers in view, each on its own peak.
    def indexed?
      lines.map(&:metric).uniq.size > 1
    end

    def average?
      @trend.average?
    end

    def axis
      @trend.axis
    end

    def none
      "Nothing"
    end

    # The busiest line of each number drawn last; [d, rank, dashed, key].
    def paths
      lines.sort_by { |line| [ line.dashed? ? 0 : 1, line.values.sum ] }.map do |line|
        d = drawn(line).each_with_index.map { |value, i| "#{i.zero? ? 'M' : 'L'}#{num(@trend.x(i))} #{num(y(value))}" }.join(" ")
        [ d, line.rank, line.dashed?, line.key ]
      end
    end

    def ticks
      return [ PEAK / 2, PEAK ].map { |value| Trend::Tick.new(value: "#{value.to_i}%", top: top(value)) } if indexed?

      scale.drop(1).map { |value| Trend::Tick.new(value: value, top: top(value)) }
    end

    def columns
      @trend.columns.map.with_index { |column, i| column.with(rows: rows_at(i), notes: []) }
    end

    def aria_label
      return @trend.aria_label if numbers == [ "commits" ]

      what = indexed? ? "Commits and site visits" : "Site visits"
      "#{what} per #{labels.unit_word} by project, #{'each number against its own peak, ' if indexed?}#{labels.words}"
    end

    def note
      return @trend.note if numbers == [ "commits" ]
      return "#{'7-day averages. ' if average?}Site visits per #{labels.unit_word}, one line per project." unless indexed?

      "#{'7-day averages. ' if average?}Solid: commits. Dotted: site visits. Each number is drawn against its own peak in the window; hover for the numbers."
    end

    def empty_note
      @hidden.values.any?(&:present?) ? "Every line is switched off. Switch one on below." : @trend.empty_note
    end

    private

    def numbers
      lines.map(&:metric).uniq
    end

    def labels
      @trend.section.labels
    end

    def commit_lines
      @trend.lines.reject { |line| off?(line.repo, "commits") }.map do |line|
        Line.new(repo: line.repo, name: line.name, rank: line.rank, metric: "commits", values: line.values)
      end
    end

    def visit_lines
      @visits.filter_map do |repo, values|
        project = @projects.find(repo)
        next unless project && values.sum.positive? && !off?(repo, "visits")

        Line.new(repo: repo, name: project.name, rank: project.rank, metric: "visits", values: values)
      end
    end

    def off?(repo, number)
      Array(@hidden[repo]).include?(number)
    end

    # Each value as a share of its number's peak over every project when
    # both numbers are in view; else as it is.
    def drawn(line)
      return line.values unless indexed?

      peak = peaks.fetch(line.metric)
      line.values.map { |value| peak.positive? ? PEAK * value / peak : 0 }
    end

    def peaks
      @peaks ||= lines.group_by(&:metric).transform_values { |each| each.flat_map(&:values).max.to_f }
    end

    # With both numbers in view, each row names its number.
    def rows_at(index)
      lines.select { |line| line.values[index].positive? }.sort_by { |line| [ line.name, line.metric ] }.map do |line|
        value = line.values[index]
        name = indexed? ? "#{line.name} · #{WORDS.fetch(line.metric)}" : line.name
        Trend::Row.new(name: name, rank: line.rank, value: average? ? format("%.1f", value) : value.round)
      end
    end

    def scale
      @scale ||= Scale.ticks([ lines.flat_map(&:values).max.to_f, average? ? 1 : 4 ].max)
    end

    def ceiling
      (indexed? ? PEAK : scale.last) * Trend::HEADROOM
    end

    def y(value)
      Trend::HEIGHT * (1 - (value / ceiling))
    end

    def top(value)
      (100.0 - (100.0 * value / ceiling)).round(2)
    end

    def num(value)
      rounded = value.to_f.round(2)
      rounded == rounded.to_i ? rounded.to_i.to_s : rounded.to_s
    end
  end
end
