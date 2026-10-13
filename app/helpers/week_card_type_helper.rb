# Type for the week card templates set in CardText::FACES. SVG text cannot flow,
# so the server measures every line; these classes make the browser draw the
# exact instance it measured, whatever size the text is set at.
module WeekCardTypeHelper
  # One class per face of the template, for a <style> inside its SVG, so the
  # downloaded PNG carries it too.
  def card_face_css(template)
    template.faces.map do |name, face|
      families = face[:families].map { |family| "'#{family}'" }.join(",")
      ".#{card_face_class(name)}{font-family:#{families};font-weight:#{face[:weight]};" \
        "font-variation-settings:#{face[:variation]};font-feature-settings:#{face[:features]}}"
    end.join.html_safe
  end

  def card_face_class(face)
    "cf-#{face.to_s.dasherize}"
  end

  # One text run of a CardLayout::Canvas. Letter-spacing goes out in pixels.
  def card_run(run)
    num = CardLayout::Shapes.method(:num)
    tag.text(run.text, x: num.call(run.x), y: num.call(run.y), class: card_face_class(run.face), "font-size": num.call(run.size),
                       "letter-spacing": (num.call(run.spacing * run.size) unless run.spacing.zero?), fill: run.fill,
                       "text-anchor": (run.anchor unless run.anchor == "start"))
  end

  # A layer's paint as path attributes: a fill, or a stroke 1px wide unless
  # it says otherwise, from the template's palette.
  def card_paint(paint, palette)
    attributes = paint[:fill] ? { fill: palette.fetch(paint[:fill]) } : { fill: "none", stroke: palette.fetch(paint[:stroke]), "stroke-width": paint[:width] || 1 }
    paint[:opacity] ? attributes.merge("fill-opacity": palette.fetch(paint[:opacity])) : attributes
  end
end
