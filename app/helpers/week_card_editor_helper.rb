# The week card editor's choices that depend on the template: a section or the
# Days choice shows only under the templates that have it, and the download
# embeds only the chosen template's fonts.
module WeekCardEditorHelper
  # Hidden under any other template than the chosen one; the editor shows and
  # hides it again as the builder switches.
  def card_choice_attributes(templates, chosen)
    { hidden: !templates.include?(chosen), data: { card_editor_target: "choice", templates: templates.map(&:key).join(" ") } }
  end

  def card_export_fonts
    WeekCardTemplate.all.to_h { |template| [ template.key, card_fonts(template.fonts) ] }
  end
end
