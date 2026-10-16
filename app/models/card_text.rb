# Advance widths of the week card's faces, so the server can lay out the
# card's text: SVG has no text flow, and the preview and the PNG must be the
# same picture. Thousandths of an em, read from the files in app/assets/fonts:
# DM Sans (by weight) and DM Mono below, for the Timeline, and every face of
# the other templates in card_text/, which script/card_fonts.py generates and
# checks against Chrome. Regenerate a table if its file changes.
module CardText
  # Every file the cards draw with, in app/assets/fonts beside its licence. The
  # editor's @font-face rules and the PNG download both load this list.
  FONTS = [
    { family: "DM Sans", style: "normal", weight: "100 1000", file: "dm-sans.woff2" },
    { family: "DM Mono", style: "normal", weight: "400", file: "dm-mono-400.woff2" },
    { family: "DM Mono", style: "normal", weight: "500", file: "dm-mono-500.woff2" },
    { family: "Newsreader", style: "normal", weight: "400 700", file: "newsreader.woff2" },
    { family: "Inter", style: "normal", weight: "400 700", file: "inter.woff2" },
    { family: "Press Start 2P", style: "normal", weight: "400", file: "press-start-2p.woff2" },
    { family: "Pixelify Sans", style: "normal", weight: "500 600", file: "pixelify-sans.woff2" },
    { family: "Tiny5", style: "normal", weight: "400", file: "tiny5.woff2" }
  ].freeze
  CHARS = ((32..126).map(&:chr) + %w[· – — − ↑ ↓ … × ’]).each_with_index.to_h.freeze
  SANS = {
    400 => [
      266, 250, 291, 804, 580, 786, 734, 159, 373, 373, 480, 550, 182, 541, 198, 392, 684, 312, 576,
      591, 607, 610, 628, 534, 608, 628, 202, 227, 550, 550, 550, 524, 1005, 664, 603, 717, 688, 565,
      535, 758, 681, 234, 501, 584, 527, 841, 691, 774, 580, 774, 594, 580, 561, 655, 669, 968, 603,
      580, 541, 314, 392, 314, 622, 660, 213, 544, 626, 572, 627, 568, 340, 558, 575, 240, 243, 504,
      223, 891, 574, 593, 626, 627, 370, 502, 392, 573, 527, 763, 496, 556, 458, 427, 234, 427, 550,
      198, 669, 873, 550, 857, 857, 566, 550, 210
    ].freeze,
    500 => [
      256, 269, 315, 820, 588, 822, 749, 171, 383, 383, 490, 559, 202, 552, 215, 403, 690, 328, 576,
      595, 621, 613, 630, 535, 616, 630, 219, 243, 559, 559, 559, 529, 1018, 678, 614, 723, 694, 571,
      542, 764, 691, 246, 514, 606, 537, 855, 703, 777, 591, 777, 605, 588, 572, 664, 681, 984, 624,
      597, 553, 334, 403, 334, 639, 680, 220, 557, 635, 583, 636, 579, 350, 570, 589, 251, 253, 527,
      237, 907, 588, 598, 635, 636, 382, 511, 405, 587, 539, 781, 520, 571, 468, 441, 246, 441, 559,
      215, 677, 887, 559, 864, 867, 604, 559, 224
    ].freeze,
    600 => [
      244, 292, 345, 841, 597, 868, 768, 186, 396, 396, 504, 571, 227, 565, 236, 417, 698, 348, 577,
      600, 638, 618, 632, 536, 625, 632, 239, 263, 571, 571, 571, 535, 1034, 695, 628, 731, 702, 578,
      550, 772, 705, 262, 530, 633, 550, 872, 719, 781, 604, 781, 620, 597, 587, 676, 695, 1004, 651,
      619, 567, 359, 417, 359, 660, 706, 228, 573, 646, 597, 646, 592, 362, 585, 606, 264, 265, 556,
      254, 926, 605, 605, 646, 646, 398, 523, 421, 604, 554, 804, 549, 590, 481, 458, 262, 458, 571,
      236, 688, 905, 571, 872, 880, 651, 571, 242
    ].freeze,
    700 => [
      236, 309, 367, 856, 604, 902, 781, 198, 405, 405, 513, 579, 246, 576, 252, 428, 704, 364, 577,
      603, 650, 621, 634, 536, 632, 634, 255, 279, 579, 579, 579, 539, 1046, 709, 638, 738, 707, 583,
      556, 777, 714, 273, 541, 653, 559, 886, 730, 783, 614, 783, 630, 604, 597, 684, 707, 1018, 670,
      635, 578, 377, 428, 377, 677, 725, 235, 586, 654, 607, 655, 602, 371, 596, 618, 274, 275, 578,
      267, 941, 617, 610, 654, 655, 409, 531, 433, 616, 566, 820, 571, 604, 490, 470, 273, 470, 579,
      252, 696, 918, 579, 878, 890, 687, 579, 255
    ].freeze
  }.freeze
  MONO = 600
  UNKNOWN = 600

  # The characters the face tables measure, in table order: Basic Latin,
  # Latin-1, Latin Extended-A and common punctuation.
  LATIN = ([ *0x20..0x7E, *0xA0..0x17F ].pack("U*") + "–—‘’‚“”„†‡•…‰‹›€™−←↑→↓▲▼").each_char.with_index.to_h.freeze
  # Each face is one instance of its fonts: the families tried for each
  # character in order, weight, axis values and features, with its widths. The
  # card pins the same values (WeekCardTypeHelper), so it draws what was measured.
  FACES = [ Inter, Newsreader, DmSans, DmMono, PressStart, PixelifySans ].map { |table| table::FACES }.reduce(:merge).freeze
  # Any other character in those faces, and one a face's files lack, which the
  # browser draws from a fallback font. Wider than every Latin glyph and than
  # the CJK fallbacks (1.000 to 1.004 em), so unknown text measures safe.
  WIDE = 1020
  # Emoji differ by platform and fight the type, so they never reach a card;
  # neither do invisible characters.
  PICTOGRAPHS = /[\p{Extended_Pictographic}\u{1F1E6}-\u{1F1FF}\u{1F3FB}-\u{1F3FF}\u{FE0E}\u{FE0F}\u{200D}\u{20E3}]/
  INVISIBLE = /[­​‌⁠﻿]/

  # Width in pixels of text at a font size, with SVG letter-spacing after every
  # character: in one of FACES, or else in DM Sans by weight or DM Mono.
  def self.width(text, size:, face: nil, weight: 400, mono: false, spacing: 0)
    chars = text.to_s.each_char.to_a
    units = if face then chars.sum { |char| face_advance(char, FACES.fetch(face)[:widths]) }
    elsif mono then chars.size * MONO
    else chars.sum { |char| advance(char, weight) }
    end
    (units * size / 1000.0) + (chars.size * spacing)
  end

  # Accented letters take their base letter's width.
  def self.advance(char, weight)
    table = SANS[SANS.keys.min_by { |known| (known - weight).abs }]
    index = CHARS[char] || CHARS[char.unicode_normalize(:nfd)[0]]
    index ? table[index] : UNKNOWN
  end

  def self.face_advance(char, widths)
    index = LATIN[char] || LATIN[char.unicode_normalize(:nfd)[0]]
    index ? widths[index] : WIDE
  end

  # The text as a card prints it: composed accents, no emoji or invisible
  # characters, single spaces.
  def self.clean(text)
    text.to_s.unicode_normalize(:nfc).gsub(PICTOGRAPHS, "").gsub(INVISIBLE, "").gsub(/[[:space:]]+/, " ").strip
  end
end
