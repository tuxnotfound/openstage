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
