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

  describe "the faces" do
    it "has a width for every character of every table" do
      expect(described_class::FACES.values.map { |face| face[:widths].size }.uniq).to eq([ described_class::LATIN.size ])
    end

    it "draws every face from files the cards load" do
      loaded = described_class::FONTS.map { |font| font[:family] }

      described_class::FACES.each_value { |face| expect(loaded).to include(*face[:families]) }
    end

    it "measures a face from its own table, plus letter-spacing" do
      widths = described_class::FACES[:inter_semibold][:widths]
      units = %w[O p e n].sum { |char| widths[described_class::LATIN[char]] }

      expect(described_class.width("Open", size: 10, face: :inter_semibold, spacing: 1)).to be_within(0.001).of((units / 100.0) + 4)
    end

    it "sets a title wider at its display size than a note at text size" do
      expect(described_class.width("Arcade", size: 1, face: :newsreader_title))
        .not_to eq(described_class.width("Arcade", size: 1, face: :newsreader_note))
    end

    it "pins tabular figures where a face asks for them" do
      expect((0..9).map { |digit| described_class.width(digit.to_s, size: 10, face: :inter_figures) }.uniq.size).to eq(1)
      expect(described_class.width("1", size: 10, face: :inter_semibold)).to be < described_class.width("0", size: 10, face: :inter_semibold)
    end

    it "takes Pixel Stage's digits from Tiny5 and its letters from Pixelify Sans" do
      expect(described_class::FACES[:pixelify_medium][:families]).to eq([ "Tiny5", "Pixelify Sans" ])
      expect(described_class.width("5", size: 10, face: :pixelify_medium)).to eq(5.0)
      expect(described_class.width("S", size: 10, face: :pixelify_medium)).to be > 5.0
    end

    it "sets Press Start 2P at one em a character" do
      expect(described_class.width("LV 29", size: 10, face: :press_start)).to eq(50.0)
    end

    it "covers Latin Extended-A, and gives other accented letters their base letter's width" do
      expect("Łódź Dvořák".chars.map { |char| described_class.width(char, size: 10, face: :newsreader_note) }).to all(be < 10)
      expect(described_class.width("ǎ", size: 10, face: :newsreader_note)).to eq(described_class.width("a", size: 10, face: :newsreader_note))
    end

    it "measures the accented letters of Central European names in DM Sans and DM Mono" do
      expect(described_class.width("ř", size: 10, face: :dm_mono_regular)).to eq(6.0)
      expect("Dvořák Łódź Zoë".chars.map { |char| described_class.width(char, size: 10, face: :dm_sans_bold) }).to all(be < 10)
    end

    it "counts a letter a face's files lack as wide, since a fallback font draws it" do
      expect(described_class.width("ĸ", size: 10, face: :dm_mono_regular)).to eq(10.2)
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
