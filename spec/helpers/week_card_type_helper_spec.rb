require "rails_helper"

RSpec.describe WeekCardTypeHelper, type: :helper do
  it "pins each face of the template to the instance the server measured" do
    css = helper.card_face_css(WeekCardTemplate.find("changelog"))

    expect(css).to include(".cf-inter-figures{font-family:'Inter';font-weight:600;" \
                           "font-variation-settings:'opsz' 14, 'wght' 600;font-feature-settings:'tnum' 1}")
    expect(css).to include(".cf-dm-mono-medium{font-family:'DM Mono';font-weight:500;font-variation-settings:normal;")
    expect(css).not_to include("Newsreader")
  end

  it "sets Pixel Stage's digits in Tiny5 before Pixelify Sans" do
    expect(helper.card_face_css(WeekCardTemplate.find("pixel_stage"))).to include(".cf-pixelify-medium{font-family:'Tiny5','Pixelify Sans';")
  end
end
