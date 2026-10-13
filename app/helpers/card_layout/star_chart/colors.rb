module CardLayout
  class StarChart
    # Three tones from one project colour: a halo that glows on the night sky,
    # a pale core, and a dot that keeps 3:1 contrast on the paper.
    module Colors
      PAPER = "#F3EDE0".freeze

      module_function

      def tones(hex)
        h, s, l = hsl(hex)
        paper_l = [ l, 0.5 ].min
        paper = from_hsl(h, [ s, 0.8 ].min, paper_l)
        while contrast(paper, PAPER) < 3 && paper_l > 0.2
          paper_l -= 0.02
          paper = from_hsl(h, [ s, 0.8 ].min, paper_l)
        end
        [ from_hsl(h, [ s, 0.85 ].min, (l + 0.08).clamp(0.62, 0.74)), from_hsl(h, [ s, 0.9 ].min, 0.9), paper ]
      end

      def rgb(hex)
        hex.delete("#").scan(/../).map { |pair| pair.to_i(16) / 255.0 }
      end

      def hsl(hex)
        r, g, b = rgb(hex)
        high, low = [ r, g, b ].max, [ r, g, b ].min
        l = (high + low) / 2
        return [ 0, 0, l ] if high == low

        d = high - low
        s = l > 0.5 ? d / (2 - high - low) : d / (high + low)
        [ hue(r, g, b, high, d) * 60, s, l ]
      end

      def hue(r, g, b, high, d)
        return ((g - b) / d) + (g < b ? 6 : 0) if high == r
        return ((b - r) / d) + 2 if high == g

        ((r - g) / d) + 4
      end

      def from_hsl(h, s, l)
        a = s * [ l, 1 - l ].min
        channel = lambda do |n|
          k = (n + (h / 30.0)) % 12
          l - (a * [ -1, [ k - 3, 9 - k, 1 ].min ].max)
        end
        "##{[ 0, 8, 4 ].map { |n| format('%02X', (channel.call(n) * 255).round) }.join}"
      end

      def luminance(hex)
        r, g, b = rgb(hex).map { |v| v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055)**2.4 }
        (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
      end

      def contrast(one, other)
        a, b = luminance(one), luminance(other)
        ([ a, b ].max + 0.05) / ([ a, b ].min + 0.05)
      end
    end
  end
end
