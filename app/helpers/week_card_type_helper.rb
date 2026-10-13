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
end
