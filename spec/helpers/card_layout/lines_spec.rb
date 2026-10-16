require "rails_helper"

RSpec.describe CardLayout::Lines do
  def lines(text, size, room, max_lines, face: :inter_medium, spacing: -0.015)
    described_class.new(text, face, spacing).balance(size, room, max_lines)
  end

  it "keeps a line whole when it fits" do
    expect(lines("Posted on X", 25, 688, 3)).to eq([ "Posted on X" ])
  end

  it "splits evenly rather than filling the first line" do
    expect(lines("Rewrote the card renderer twice, and now the fonts measure the same everywhere", 18.5, 688, 3))
      .to eq([ "Rewrote the card renderer twice, and now", "the fonts measure the same everywhere" ])
  end

  it "does not end a line on a short word when another split fits" do
    expect(lines("Why I stopped coding for a week to talk to twenty users", 42, 688, 3))
      .to eq([ "Why I stopped coding for a week", "to talk to twenty users" ])
  end

  it "breaks after a hyphen only when spaces are not enough" do
    expect(lines("build-in-public-newsletter-archive", 16, 200, 3)).to eq([ "build-in-public-", "newsletter-archive" ])
  end

  it "gives up past the lines it may use" do
    expect(lines("Alexandra Konstantinopoulou-Vasquez", 15, 194, 2, face: :inter_semibold, spacing: -0.01)).to be_nil
  end
end

RSpec.describe CardLayout::Type do
  it "cuts a project name at its last hyphen inside the limit" do
    expect(described_class.cut_name("build-in-public-newsletter-archive", 22)).to eq("build-in-public…")
    expect(described_class.cut_name("openstage", 22)).to eq("openstage")
  end

  it "cuts at a word, without a stray comma before the ellipsis" do
    cut = described_class.cut_words("Answer every support email, before lunch on weekdays", :inter_semibold, 26, -0.01, 420)

    expect(cut).to eq("Answer every support email…")
    expect(described_class.width(cut, :inter_semibold, 26, -0.01)).to be <= 420
  end

  it "leaves the last character's letter-spacing out of the width" do
    expect(described_class.width("AB", :dm_mono_medium, 10, 0.1)).to be_within(0.001).of(12 + 1)
  end
end
