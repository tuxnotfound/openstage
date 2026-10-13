module CardLayout
  # What a card draws: text runs, each in a CardText face at its place; shapes
  # as SVG path data, one string per layer; small dots; and icons. A layout
  # fills it, and the template's partial writes it out in that order.
  class Canvas
    # spacing is letter-spacing in ems; x is the anchor.
    Run = Data.define(:text, :face, :size, :x, :y, :fill, :spacing, :anchor)
    Dot = Data.define(:cx, :cy, :r, :fill)
    Icon = Data.define(:x, :y, :size, :view_box, :path, :fill)

    attr_reader :runs, :paths, :dots, :icons

    def initialize(layers)
      @runs = []
      @dots = []
      @icons = []
      @paths = layers.index_with { +"" }
    end

    # Sets text from x on a baseline, and says where it ends.
    def put(text, face, size, x, baseline, fill, spacing: 0)
      runs << Run.new(text: text, face: face, size: size, x: x, y: baseline, fill: fill, spacing: spacing, anchor: "start")
      x + Type.width(text, face, size, spacing)
    end

    # Sets text to end at x, and says where it starts. SVG adds the tracking
    # after the last glyph too, so the anchor moves right by one spacing.
    def put_end(text, face, size, x, baseline, fill, spacing: 0)
      runs << Run.new(text: text, face: face, size: size, x: x + (spacing * size), y: baseline, fill: fill,
                      spacing: spacing, anchor: "end")
      x - Type.width(text, face, size, spacing)
    end

    def draw(layer, path)
      paths.fetch(layer) << path
    end

    def dot(cx, cy, r, fill)
      dots << Dot.new(cx: cx, cy: cy, r: r, fill: fill)
    end

    def icon(x, y, size, view_box, path, fill)
      icons << Icon.new(x: x, y: y, size: size, view_box: view_box, path: path, fill: fill)
    end
  end
end
