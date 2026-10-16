module CardLayout
  # Shapes as SVG path data, written to two decimals.
  module Shapes
    module_function

    def num(value)
      rounded = value.to_f.round(2)
      rounded == rounded.to_i ? rounded.to_i.to_s : rounded.to_s
    end

    # A rounded rectangle.
    def rounded(x, y, width, height, radius)
      k = [ radius, width / 2.0, height / 2.0 ].min
      r = "#{num(k)} #{num(k)} 0 0 1"
      "M#{num(x + k)} #{num(y)}H#{num(x + width - k)}A#{r} #{num(x + width)} #{num(y + k)}" \
        "V#{num(y + height - k)}A#{r} #{num(x + width - k)} #{num(y + height)}H#{num(x + k)}" \
        "A#{r} #{num(x)} #{num(y + height - k)}V#{num(y + k)}A#{r} #{num(x + k)} #{num(y)}Z"
    end

    # A rounded rectangle to stroke at 1px: on half pixels, so it stays crisp.
    def outline(x, y, width, height, radius)
      rounded(x.round + 0.5, y.round + 0.5, width.round - 1, height.round - 1, radius)
    end

    # A 1px horizontal rule.
    def rule(from, to, y)
      "M#{num(from)} #{num(y.round + 0.5)}H#{num(to)}"
    end
  end
end
