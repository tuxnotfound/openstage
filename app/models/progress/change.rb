module Progress
  # A value against the window before, as the pages write a change: the
  # arrow, which carries the direction, the percent, and whether it went up
  # ("±" and "0%", neither up nor down, for none).
  Change = Data.define(:arrow, :text, :up) do
    # nil with nothing before to compare with.
    def self.of(value, previous)
      return unless previous&.positive?

      percent = ((100.0 * value / previous) - 100).round
      return new(arrow: "±", text: "0%", up: nil) if percent.zero?

      new(arrow: percent.negative? ? "▼" : "▲", text: "#{percent.abs}%", up: percent.positive?)
    end
  end
end
