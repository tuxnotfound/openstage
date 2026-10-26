module ProgressChart
  # A number other than commits, on its own scale: a line per project, in its
  # colour, on the commit chart's points, so charts stacked under it line up
  # with it point for point and their tooltips name the same days.
  class Series
    Line = Data.define(:repo, :name, :rank, :values)

    # trend: the section's Trend; values: {repo's full name => one value per
    # point}; projects: the section's Progress::Projects; name: "Site visits".
    def initialize(trend, values:, projects:, name:)
      @trend = trend
      @values = values
      @projects = projects
      @name = name
    end

    # The projects with any of it in the window, busiest of all time first.
    def lines
      @lines ||= @values.filter_map do |repo, values|
        project = @projects.find(repo)
        Line.new(repo: repo, name: project.name, rank: project.rank, values: values) if project && values.sum.positive?
      end.sort_by { |line| line.rank || Float::INFINITY }
    end

    def average?
      @trend.average?
    end

    def axis
      @trend.axis
    end

    def none
      "No #{@name.downcase}"
    end

    # The busiest drawn last, on top.
    def paths
      lines.sort_by { |line| line.values.sum }.map do |line|
        [ line.values.each_with_index.map { |value, i| "#{i.zero? ? 'M' : 'L'}#{num(@trend.x(i))} #{num(y(value))}" }.join(" "), line.rank ]
      end
    end

    def ticks
      scale.drop(1).map { |value| Trend::Tick.new(value: value, top: top(value)) }
    end

    def columns
      @trend.columns.map.with_index { |column, i| column.with(rows: rows_at(i), notes: []) }
    end

    def aria_label
      "#{average? ? "7-day average of #{@name.downcase} per day" : "#{@name} per #{labels.unit_word}"} by project, #{labels.words}"
    end

    def note
      average? ? "A 7-day average of #{@name.downcase} per day, one line per project." : "#{@name} per #{labels.unit_word}, one line per project."
    end

    def empty_note
      "No #{@name.downcase} #{labels.word}."
    end

    private

    def labels
      @trend.section.labels
    end

    def rows_at(index)
      lines.select { |line| line.values[index].positive? }.sort_by { |line| -line.values[index] }.map do |line|
        Trend::Row.new(name: line.name, rank: line.rank, value: average? ? format("%.1f", line.values[index]) : line.values[index].round)
      end
    end

    def scale
      @scale ||= Scale.ticks([ lines.flat_map(&:values).max.to_f, average? ? 1 : 4 ].max)
    end

    def ceiling
      scale.last * Trend::HEADROOM
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
