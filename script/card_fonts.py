"""The week card's Newsreader and Inter: the files the browser draws with, and
the width tables the server lays text out with (app/models/card_text/).

The card is an SVG, which cannot flow text, so the server measures every line
and places it. Those measurements are only true for the exact files the page
loads, so both are made here, and the tables are made from the files.

Needs Python 3 with fontTools and brotli:
  python3 -m venv /tmp/fontvenv && /tmp/fontvenv/bin/pip install fonttools brotli

1. Subset the variable fonts from Google Fonts (github.com/google/fonts, under
   ofl/newsreader and ofl/inter) to Latin woff2 in app/assets/fonts:
  /tmp/fontvenv/bin/python script/card_fonts.py subset \
    'Newsreader[opsz,wght].ttf' 'Newsreader-Italic[opsz,wght].ttf' 'Inter[opsz,wght].ttf'

2. Measure the shipped files into app/models/card_text/newsreader.rb and inter.rb:
  /tmp/fontvenv/bin/python script/card_fonts.py widths

Run step 2 again whenever a font file or a face below changes.
"""
import math
import sys
import textwrap
import unicodedata
from io import BytesIO
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parent.parent
FONTS = ROOT / "app/assets/fonts"
OUT = ROOT / "app/models/card_text"

# The card uses weights 400 to 700; every optical size is kept.
WEIGHTS = (400, 700)
UNICODES = [*range(0x20, 0x7F), *range(0xA0, 0x180), *range(0x300, 0x370), *range(0x2000, 0x2070),
            0x20AC, 0x2122, *range(0x2190, 0x2194), 0x2212, 0x25B2, 0x25BC]

# The characters the tables cover, in table order. CardText::LATIN builds the
# same list; a spec checks that every table has one width per character.
CHARS = [chr(c) for c in [*range(0x20, 0x7F), *range(0xA0, 0x180)]] + list("–—‘’‚“”„†‡•…‰‹›€™−←↑→↓▲▼")
# Wider than any Latin glyph and than the CJK fallbacks (1.000 to 1.004 em),
# so text the tables do not know still measures on the safe side.
UNKNOWN = 1020

FILES = {
    "newsreader.woff2": ("Newsreader", "normal"),
    "newsreader-italic.woff2": ("Newsreader", "italic"),
    "inter.woff2": ("Inter", "normal"),
}

# Every instance the card sets, by name: file, weight, optical size and OpenType
# features. The SVG pins the same values, so it draws what was measured.
FACES = {
    "Newsreader": {
        "newsreader_display": ("newsreader.woff2", 500, 72, "'lnum' 1"),
        "newsreader_text": ("newsreader.woff2", 500, 18, "'lnum' 1"),
        "newsreader_text_regular": ("newsreader.woff2", 400, 18, "'lnum' 1"),
        "newsreader_figures": ("newsreader.woff2", 500, 48, "'lnum' 1, 'tnum' 1"),
        "newsreader_italic": ("newsreader-italic.woff2", 400, 20, "'lnum' 1"),
    },
    "Inter": {
        "inter_medium": ("inter.woff2", 500, 14, "normal"),
        "inter_semibold": ("inter.woff2", 600, 14, "normal"),
        "inter_bold": ("inter.woff2", 700, 14, "normal"),
        "inter_figures": ("inter.woff2", 600, 14, "'tnum' 1"),
    },
}


def subset_fonts(sources):
    for source, name in zip(sources, FILES):
        # Saved and read back before subsetting: the subsetter trips on the
        # instancer's half-loaded glyph variations otherwise.
        limited = BytesIO()
        instantiateVariableFont(TTFont(source), {"wght": WEIGHTS}).save(limited)
        font = TTFont(BytesIO(limited.getvalue()))
        options = subset.Options()
        options.flavor = "woff2"
        options.layout_features += ["tnum", "lnum", "pnum", "onum", "case"]
        subsetter = subset.Subsetter(options)
        subsetter.populate(unicodes=UNICODES)
        subsetter.subset(font)
        font.flavor = "woff2"
        font.save(FONTS / name)
        print(FONTS / name)


# Glyph substitutions of the features a face turns on, such as tabular figures.
def substitutions(font, features):
    gsub = font["GSUB"].table
    mapping = {}
    for record in gsub.FeatureList.FeatureRecord:
        if f"'{record.FeatureTag}' 1" not in features:
            continue
        for index in record.Feature.LookupListIndex:
            for table in gsub.LookupList.Lookup[index].SubTable:
                mapping.update(getattr(getattr(table, "ExtSubTable", table), "mapping", {}))
    return mapping


# Thousandths of an em, rounded up so a sum never comes out narrower than the
# browser draws it. A character the font lacks takes its base letter's width
# when it has one.
def widths(file, weight, opsz, features):
    font = TTFont(FONTS / file)
    glyphs = font.getGlyphSet(location={"wght": weight, "opsz": opsz})
    cmap = font.getBestCmap()
    swap = substitutions(font, features)
    units = font["head"].unitsPerEm
    out = []
    for char in CHARS:
        glyph = cmap.get(ord(char)) or cmap.get(ord(unicodedata.normalize("NFD", char)[0]))
        out.append(math.ceil(glyphs[swap.get(glyph, glyph)].width * 1000 / units - 1e-9) if glyph else UNKNOWN)
    return out


def ruby_face(name, file, weight, opsz, features):
    family, style = FILES[file]
    numbers = textwrap.fill(", ".join(str(w) for w in widths(file, weight, opsz, features)), width=104,
                            initial_indent=" " * 10, subsequent_indent=" " * 10)
    return (f"      {name}: {{\n"
            f"        family: \"{family}\", style: \"{style}\", weight: {weight}, opsz: {opsz}, features: \"{features}\",\n"
            f"        widths: [\n{numbers}\n        ].freeze\n      }}.freeze")


def write_widths():
    for family, faces in FACES.items():
        files = sorted({face[0] for face in faces.values()})
        body = ",\n".join(ruby_face(name, *face) for name, face in faces.items())
        path = OUT / f"{family.lower()}.rb"
        path.write_text(
            f"# Advance widths of {family} for CardText, by face: thousandths of an em for\n"
            f"# each character of CardText::LATIN. Generated by script/card_fonts.py from\n"
            f"# app/assets/fonts/{' and '.join(files)}; run it again, do not edit.\n"
            f"module CardText\n  module {family}\n    FACES = {{\n{body}\n    }}.freeze\n  end\nend\n")
        print(path)


if __name__ == "__main__":
    if sys.argv[1:2] == ["subset"] and len(sys.argv) == 5:
        subset_fonts(sys.argv[2:])
    elif sys.argv[1:] == ["widths"]:
        write_widths()
    else:
        sys.exit(__doc__)
