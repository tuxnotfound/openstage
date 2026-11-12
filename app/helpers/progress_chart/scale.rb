module ProgressChart
  # The value axis of a chart of counts: about three steps of 1, 2, 2.5 (from
  # 25 up), 5 or 10 times a power of ten, so the gridlines never land on half
  # a commit. The plot keeps its height in every period, so bars never jump.
  class Scale
    attr_reader :ticks

    def initialize(max, top:, bottom:)
      @ticks = self.class.ticks([ max, 4 ].max)
      @top = top
      @bottom = bottom
    end

    def self.ticks(max)
      raw = max / 3.0
      power = 10**Math.log10(raw).floor
      step = step_for(raw / power, power) * power
      count = (max / step.to_f - 1e-9).ceil
      (0..count).map { |k| whole(k * step) }
    end

    # The two gridlines of an axis over max, its middle and its top: a step
    # of one significant figure, rounded up from half of max, and twice it,
    # so both read as round numbers (20 and 40 over 37). whole: a count
    # never splits, so the step is at least 1.
    def self.two_steps(max, whole: true)
      raw = [ max.to_f, whole ? 2 : 0 ].max / 2
      return [ 1, 2 ] unless raw.positive?

      power = 10.0**Math.log10(raw).floor
      step = (((raw / power) - 1e-9).ceil * power).round(6)
      step = step.round if step == step.round
      [ step, step * 2 ]
    end

    def self.step_for(mantissa, power)
      if mantissa <= 1 then 1
      elsif mantissa <= 2 then 2
      elsif mantissa <= 2.5 && power >= 10 then 2.5
      elsif mantissa <= 5 then 5
      else 10
      end
    end

    def self.whole(value)
      value.round(1) == value.round ? value.round : value.round(1)
    end
    private_class_method :step_for, :whole

    def y(value)
      @bottom - (value.to_f / ticks.last * (@bottom - @top))
    end
  end
end
