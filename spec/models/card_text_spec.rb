require "rails_helper"

RSpec.describe CardText do
  it "measures DM Sans by weight, wider when bolder" do
    regular = described_class.width("Openstage", size: 20)
    bold = described_class.width("Openstage", size: 20, weight: 700)

    expect(regular).to be_within(0.01).of(20 * (774 + 626 + 568 + 574 + 502 + 392 + 544 + 558 + 568) / 1000.0)
    expect(bold).to be > regular
  end

  it "measures DM Mono at six tenths of an em, plus letter-spacing" do
    expect(described_class.width("W41", size: 10, mono: true, spacing: 1)).to eq(21.0)
  end

  it "gives an accented letter its base letter's width" do
    expect(described_class.width("é", size: 10)).to eq(described_class.width("e", size: 10))
  end

  describe "the Newsreader and Inter faces" do
    it "has a width for every character of every table" do
      expect(described_class::FACES.values.map { |face| face[:widths].size }.uniq).to eq([ described_class::LATIN.size ])
    end

    it "measures a face from its own table, plus letter-spacing" do
      widths = described_class::FACES[:inter_semibold][:widths]
      units = %w[O p e n].sum { |char| widths[described_class::LATIN[char]] }

      expect(described_class.width("Open", size: 10, face: :inter_semibold, spacing: 1)).to be_within(0.001).of((units / 100.0) + 4)
    end

    it "sets the lead wider at its display size than the rows at text size" do
      expect(described_class.width("Arcade", size: 1, face: :newsreader_display))
        .not_to eq(described_class.width("Arcade", size: 1, face: :newsreader_text))
    end

    it "pins tabular figures where a face asks for them" do
      %i[newsreader_figures inter_figures].each do |face|
        expect((0..9).map { |digit| described_class.width(digit.to_s, size: 10, face: face) }.uniq.size).to eq(1)
      end
      expect(described_class.width("1", size: 10, face: :inter_semibold)).to be < described_class.width("0", size: 10, face: :inter_semibold)
    end

    it "covers Latin Extended-A, and gives other accented letters their base letter's width" do
      expect("Łódź Dvořák".chars.map { |char| described_class.width(char, size: 10, face: :newsreader_text) }).to all(be < 10)
      expect(described_class.width("ǎ", size: 10, face: :newsreader_text)).to eq(described_class.width("a", size: 10, face: :newsreader_text))
    end

    it "counts any other character as wider than an em, so a fit errs safe" do
      expect(described_class.width("漢字", size: 10, face: :inter_medium)).to eq(20.4)
    end
  end

  it "keeps emoji and invisible characters off the card" do
    expect(described_class.clean("Drift physics  finally feel right \u{1F3C1}\u{1F525}")).to eq("Drift physics finally feel right")
    expect(described_class.clean("Zoë​ ships")).to eq("Zoë ships")
  end
end
