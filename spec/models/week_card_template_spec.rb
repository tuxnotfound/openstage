require "rails_helper"

RSpec.describe WeekCardTemplate do
  it "offers Changelog first, as the default, then Star Chart, Pixel Stage and Timeline" do
    expect(described_class.keys).to eq(%w[changelog star_chart pixel_stage timeline])
    expect(WeekCard.new.style).to eq("changelog")
    expect(WeekCard::STYLES).to eq(described_class.keys)
  end

  it "finds a template by its key, and Changelog for anything else" do
    expect(described_class.find("star_chart").name).to eq("Star Chart")
    expect(described_class.find("weekly_brief").key).to eq("changelog")
  end

  it "has only sections the card knows" do
    described_class.all.each do |template|
      expect(WeekCard::SECTIONS).to include(*template.sections)
    end
  end

  it "says which sections each template draws" do
    expect(described_class.find("changelog")).to have_attributes(partial: "week_cards/changelog")
    expect(described_class.find("changelog").has?("activity")).to be(true)
    expect(described_class.find("changelog").has?("history")).to be(false)
    expect(described_class.find("star_chart").sections).to include("history")
    expect(described_class.find("pixel_stage").has?("building")).to be(true)
  end

  it "has a font file and a face for each family it draws with" do
    described_class.all.each do |template|
      expect(template.fonts.map { |font| font[:family] }.uniq).to match_array(template.families)
    end
    expect(described_class.find("changelog").faces.keys).to include(:inter_medium, :inter_figures, :dm_mono_medium)
    expect(described_class.find("changelog").faces.keys).not_to include(:newsreader_title)
    expect(described_class.find("pixel_stage").fonts.map { |font| font[:file] })
      .to contain_exactly("press-start-2p.woff2", "pixelify-sans.woff2", "tiny5.woff2")
  end

  it "keeps all seven days on Pixel Stage" do
    expect(described_class.all.reject(&:days_choice).map(&:key)).to eq([ "pixel_stage" ])
  end
end
