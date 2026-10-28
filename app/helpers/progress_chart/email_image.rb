module ProgressChart
  # The page's chart (Trend) for an email: mail clients run no script and
  # Gmail shows no SVG, so it is drawn as SVG here and sent as a PNG attached
  # inline. Twice the size it shows at, for sharp screens; light colours only,
  # since an email cannot follow the reader's dark mode.
  class EmailImage
    FILE = "week-chart.png".freeze
    # Shown at 600 by 240.
    WIDTH = 1200
    HEIGHT = 480
    PLOT = { left: 64, right: 1176, top: 28, bottom: 416 }.freeze
    INK = "#0E0F12".freeze
    MUTED = "#666A73".freeze
    LINE = "#E2E4E8".freeze
    FONT = "Liberation Sans, Helvetica, Arial, sans-serif".freeze

    def initialize(chart)
      @chart = chart
    end

    def png
      Vips::Image.svgload_buffer(svg).write_to_buffer(".png")
    end

    def svg
      parts = [ %(<svg xmlns="http://www.w3.org/2000/svg" width="#{WIDTH}" height="#{HEIGHT}" font-family="#{FONT}">),
                %(<rect width="#{WIDTH}" height="#{HEIGHT}" fill="#FFFFFF"/>) ]
      parts.concat(gridlines, lines, frame, axis, discs)
      parts << "</svg>"
      parts.join
    end

    # Words for the image's alt: the projects and their commits.
    def summary
      @chart.lines.map { |line| "#{line.name} #{line.total}" }.join(", ")
    end

    private

    def gridlines
      @chart.ticks.flat_map do |tick|
        y = y_at(tick.top)
        [ %(<line x1="#{PLOT[:left]}" x2="#{PLOT[:right]}" y1="#{y}" y2="#{y}" stroke="#{LINE}" stroke-width="2" stroke-dasharray="6 6"/>),
          %(<text x="#{PLOT[:left] - 14}" y="#{y + 8}" text-anchor="end" font-size="24" fill="#{MUTED}">#{tick.value}</text>) ]
      end
    end

    # The busiest project last, so it draws on top.
    def lines
      @chart.lines.reverse.map do |line|
        points = line.values.each_with_index.map { |value, i| "#{x_at(i)},#{y_at(@chart.top(value))}" }.join(" ")
        %(<polyline points="#{points}" fill="none" stroke="#{color(line.rank)}" stroke-width="6" stroke-linejoin="round" stroke-linecap="round"/>)
      end
    end

    # The baseline, and a line at the right edge when it is today.
    def frame
      base = %(<line x1="#{PLOT[:left]}" x2="#{PLOT[:right]}" y1="#{PLOT[:bottom]}" y2="#{PLOT[:bottom]}" stroke="#{INK}" stroke-width="4"/>)
      return [ base ] unless @chart.tally.period.buckets.last.current

      [ base, %(<line x1="#{PLOT[:right]}" x2="#{PLOT[:right]}" y1="#{PLOT[:top]}" y2="#{PLOT[:bottom]}" stroke="#{INK}" stroke-width="4"/>) ]
    end

    # Every point named on a week; the first, the middle and today otherwise.
    def axis
      buckets = @chart.tally.period.buckets
      named = buckets.size <= 8 ? buckets.map(&:index) : [ 0, buckets.size / 2, buckets.size - 1 ]
      named.map do |i|
        today = i == buckets.size - 1 && buckets[i].current
        text = today ? "Today" : @chart.labels_for(buckets[i])
        anchor = { 0 => "start", buckets.size - 1 => "end" }.fetch(i, "middle")
        %(<text x="#{x_at(i)}" y="#{PLOT[:bottom] + 44}" text-anchor="#{anchor}" font-size="24" ) +
          %(font-weight="#{today ? 700 : 400}" fill="#{today ? INK : MUTED}">#{ERB::Util.h(text)}</text>)
      end
    end

    def discs
      @chart.discs.map do |disc|
        cx = PLOT[:left] + (disc.left / 100.0 * (PLOT[:right] - PLOT[:left]))
        cy = y_at(disc.top)
        fill = color(disc.rank)
        %(<circle cx="#{cx.round(1)}" cy="#{cy}" r="26" fill="#{fill}" stroke="#FFFFFF" stroke-width="4"/>) +
          %(<text x="#{cx.round(1)}" y="#{cy + 9}" text-anchor="middle" font-size="24" font-weight="700" fill="#{Palette.ink_on(fill)}">#{disc.number}</text>)
      end
    end

    def x_at(index)
      (PLOT[:left] + (@chart.x(index) / Trend::WIDTH * (PLOT[:right] - PLOT[:left]))).round(1)
    end

    # A height in percent from the top of the plot, in pixels.
    def y_at(percent)
      (PLOT[:top] + (percent / 100.0 * (PLOT[:bottom] - PLOT[:top]))).round(1)
    end

    # A project's colour; ink for no project, and past the palette.
    def color(rank)
      Palette.project_color(rank) || INK
    end
  end
end
