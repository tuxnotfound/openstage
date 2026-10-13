module CardLayout
  # Colour arithmetic the templates share, on "#RRGGBB" strings.
  module Paint
    module_function

    # From one colour toward another by a share, rounded per channel.
    def mix(from, to, share)
      from, to = [ from, to ].map { |hex| channels(hex) }
      "##{from.zip(to).map { |a, b| format('%02X', (a + ((b - a) * share) + 0.5).floor) }.join}"
    end

    def channels(hex)
      hex.delete("#").scan(/../).map { |pair| pair.to_i(16) }
    end

    def luminance(hex)
      r, g, b = channels(hex).map { |v| v / 255.0 }.map { |v| v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055)**2.4 }
      (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
    end

    def contrast(one, other)
      a, b = luminance(one), luminance(other)
      ([ a, b ].max + 0.05) / ([ a, b ].min + 0.05)
    end
  end
end
