module CardLayout
  class PixelStage
    # The mock's seeded random numbers, bit for bit, so the scene's stars,
    # pines, grass and flowers land where they do in the mock: a JavaScript
    # mulberry32 seeded from an FNV-1a hash of the handle and the week's
    # Monday. Every value is kept as an unsigned 32-bit integer.
    class Random
      MASK = 0xFFFFFFFF

      def self.hash(text)
        text.each_char.inject(2_166_136_261) { |h, char| imul(h ^ char.ord, 16_777_619) }
      end

      def self.imul(a, b)
        ((a & MASK) * (b & MASK)) & MASK
      end

      def initialize(handle, monday)
        @seed = self.class.hash(handle) ^ self.class.imul(monday.strftime("%Y%m%d").to_i, 2_654_435_761)
      end

      def rand
        @seed = (@seed + 0x6D2B79F5) & MASK
        t = self.class.imul(@seed ^ (@seed >> 15), 1 | @seed)
        t = ((t + self.class.imul(t ^ (t >> 7), 61 | t)) & MASK) ^ t
        ((t ^ (t >> 14)) & MASK) / 4_294_967_296.0
      end
    end
  end
end
