require "rails_helper"

RSpec.describe ShareCardHelper do
  # Funnel Sans at 20px fits a letter in every 9.6px, so 13 letters in 125px.
  describe "#share_card_lines" do
    it "fills each line with whole words" do
      expect(helper.share_card_lines("one two three four", width: 125, size: 20, lines: 3)).to eq([ "one two three", "four" ])
    end

    it "cuts the last line with … when the text runs on" do
      expect(helper.share_card_lines("one two three four five six seven", width: 68, size: 20, lines: 2)).to eq([ "one two", "three…" ])
    end

    it "cuts a word longer than a line" do
      expect(helper.share_card_lines("supercalifragilistic", width: 96, size: 20, lines: 2)).to eq([ "supercali…" ])
    end

    it "draws no line for no text" do
      expect(helper.share_card_lines(nil, width: 240, size: 20, lines: 2)).to eq([])
    end
  end

  describe "#share_card_fit" do
    it "picks the largest size the text fits at" do
      expect(helper.share_card_fit("openstage", width: 300, sizes: [ 76, 52, 40 ], font: ShareCardHelper::DISPLAY)).to eq([ "openstage", 52 ])
    end

    it "cuts the text at the smallest size when it fits none" do
      expect(helper.share_card_fit("a very long project name", width: 200, sizes: [ 40, 20 ])).to eq([ "a very long project…", 20 ])
    end
  end

  describe "#share_card_segments" do
    it "splits the bar by share, with gaps, the widest part giving way to the smallest" do
      parts = helper.share_card_segments([ 98, 2 ], x: 0, width: 106, gap: 6, min: 12)

      expect(parts).to eq([ [ 0, 88.0 ], [ 94.0, 12 ] ])
    end
  end

  describe "#share_card_initials" do
    it "takes the first letters of the builder's first two names" do
      expect(helper.share_card_initials(build(:user, display_name: "bea van builder"))).to eq("BV")
    end
  end
end
