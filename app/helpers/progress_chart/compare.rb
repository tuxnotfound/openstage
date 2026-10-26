module ProgressChart
  # Commits and site visits on one chart, on the section's points: a line per
  # project and number, in the project's colour, commits solid and visits
  # dotted. A week's commits and a week's visits share no scale, so each
  # number is drawn against its own peak in the window, its projects on one
  # scale so they still compare; the tooltip keeps the real numbers. It
  # answers what Trend answers, so the chart partial draws it.
  class Compare
    # metric: "commits" or "visits"; values: real, one per point.
    Line = Data.define(:repo, :name, :rank, :metric, :values) do
      def dashed?
        metric == "visits"
      end
    end
    PEAK = 100.0
    WORDS = { "commits" => "commits", "visits" => "site visits" }.freeze

    # trend: the section's Trend; visits: {repo's full name => visits per
    # point}; projects: the section's Progress::Projects.
    def initialize(trend, visits:, projects:)
      @trend = trend
      @visits = visits
      @projects = projects
    end

    def lines
      @lines ||= commit_lines + visit_lines
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

    # The busiest line of each number drawn last; [d, rank, dashed].
    def paths
      lines.sort_by { |line| [ line.dashed? ? 0 : 1, line.values.sum ] }.map do |line|
        d = drawn(line).each_with_index.map { |value, i| "#{i.zero? ? 'M' : 'L'}#{num(@trend.x(i))} #{num(y(value))}" }.join(" ")
        [ d, line.rank, line.dashed? ]
      end
    end

    def ticks
      [ PEAK / 2, PEAK ].map { |value| Trend::Tick.new(value: "#{value.to_i}%", top: top(value)) }
    end

    def columns
      @trend.columns.map.with_index { |column, i| column.with(rows: rows_at(i), notes: []) }
    end

    def aria_label
      "Commits and site visits per #{@trend.section.labels.unit_word} by project, each number against its own peak, #{@trend.section.labels.words}"
    end

    def note
      "#{'7-day averages. ' if average?}Solid: commits. Dotted: site visits. Each number is drawn against its own peak in the window; hover for the numbers."
    end

    def empty_note
      @trend.empty_note
    end

    private

    def commit_lines
      @trend.lines.map { |line| Line.new(repo: line.repo, name: "#{line.name} · commits", rank: line.rank, metric: "commits", values: line.values) }
    end

    def visit_lines
      @visits.filter_map do |repo, values|
        project = @projects.find(repo)
        next unless project && values.sum.positive?

        Line.new(repo: repo, name: "#{project.name} · #{WORDS.fetch('visits')}", rank: project.rank, metric: "visits", values: values)
      end
    end

    # Each value as a share of its number's peak, over every project.
    def drawn(line)
      peak = peaks.fetch(line.metric)
      line.values.map { |value| peak.positive? ? PEAK * value / peak : 0 }
    end

    def peaks
      @peaks ||= lines.group_by(&:metric).transform_values { |each| each.flat_map(&:values).max.to_f }
    end

    def rows_at(index)
      lines.select { |line| line.values[index].positive? }.sort_by { |line| [ line.name ] }.map do |line|
        value = line.values[index]
        Trend::Row.new(name: line.name, rank: line.rank, value: average? ? format("%.1f", value) : value.round)
      end
    end

    def ceiling
      PEAK * Trend::HEADROOM
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
