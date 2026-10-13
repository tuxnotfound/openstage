"""The week card's fonts: the files the browser draws with, the width tables the
server lays text out with (app/models/card_text/), and a check of those tables
against Chrome.

The card is an SVG, which cannot flow text, so the server measures every line
and places it. Those measurements are only true for the exact files the page
loads, so both are made here, and the tables are made from the files.

Needs Python 3 with fontTools and brotli, and Google Chrome for the check:
  python3 -m venv /tmp/fontvenv && /tmp/fontvenv/bin/pip install fonttools brotli

1. Cut the Google Fonts sources (github.com/google/fonts, under ofl/<family>)
   to woff2 in app/assets/fonts. Name only the sources that changed:
  /tmp/fontvenv/bin/python script/card_fonts.py subset 'PixelifySans[wght].ttf' ...

2. Measure the shipped files into app/models/card_text/:
  /tmp/fontvenv/bin/python script/card_fonts.py widths

3. Draw every face in Chrome and compare its widths with the tables. Fails when
   Chrome draws any sample more than 1% wider than the tables say:
  /tmp/fontvenv/bin/python script/card_fonts.py check

Run steps 2 and 3 again whenever a font file or a face below changes.
"""
import json
import math
import subprocess
import sys
import tempfile
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
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

LATIN = [*range(0x20, 0x7F), *range(0xA0, 0x180), *range(0x300, 0x370), *range(0x2000, 0x2070),
         0x20AC, 0x2122, *range(0x2190, 0x2194), 0x2212, 0x25B2, 0x25BC]
DIGITS = list(range(0x30, 0x3A))

# The characters the tables cover, in table order. CardText::LATIN builds the
# same list; a spec checks that every table has one width per character.
CHARS = [chr(c) for c in [*range(0x20, 0x7F), *range(0xA0, 0x180)]] + list("–—‘’‚“”„†‡•…‰‹›€™−←↑→↓▲▼")
# Wider than any Latin glyph and than the CJK fallbacks (1.000 to 1.004 em),
# so text the tables do not know still measures on the safe side.
UNKNOWN = 1020

# Every file the cards load: its family and the weights its @font-face rule
# declares (as CardText::FONTS does), the source it is cut from, the axes it
# keeps as a range or pins to one value, and the characters it keeps. DM Sans
# and DM Mono came already cut, so they are only measured here. Press Start 2P
# has a Reserved Font Name, so a cut copy would need another name: it ships
# whole, only rewrapped as woff2. Tiny5 keeps only its digits: Pixel Stage
# takes them over Pixelify Sans, whose 5 reads as an S.
FILES = {
    "newsreader.woff2": ("Newsreader", "400 700", "Newsreader[opsz,wght].ttf", {"wght": (400, 700)}, LATIN),
    "inter.woff2": ("Inter", "400 700", "Inter[opsz,wght].ttf", {"wght": (400, 700)}, LATIN),
    "dm-sans.woff2": ("DM Sans", "100 1000", None, None, None),
    "dm-mono-400.woff2": ("DM Mono", "400", None, None, None),
    "dm-mono-500.woff2": ("DM Mono", "500", None, None, None),
    "press-start-2p.woff2": ("Press Start 2P", "400", "PressStart2P-Regular.ttf", None, None),
    "pixelify-sans.woff2": ("Pixelify Sans", "500 600", "PixelifySans[wght].ttf", {"wght": (500, 600)}, LATIN),
    "tiny5.woff2": ("Tiny5", "400", "Tiny5[BLED,JITT,ROND,wdth,wght].ttf",
                    {"wght": 400, "wdth": 100, "ROND": 0, "BLED": 0, "JITT": 0}, DIGITS),
}

# Every instance the cards set, by name, grouped by the module that holds its
# widths: the files the browser tries for each character in order, weight,
# optical size (None for a font without one) and OpenType features. The SVG
# pins the same values, so it draws what was measured.
FACES = {
    "Inter": {
        "inter_regular": (["inter.woff2"], 400, 14, "normal"),
        "inter_medium": (["inter.woff2"], 500, 14, "normal"),
        "inter_semibold": (["inter.woff2"], 600, 14, "normal"),
        "inter_figures": (["inter.woff2"], 600, 14, "'tnum' 1"),
    },
    "Newsreader": {
        "newsreader_title": (["newsreader.woff2"], 400, 48, "normal"),
        "newsreader_note": (["newsreader.woff2"], 400, 15, "normal"),
    },
    "DmSans": {
        "dm_sans_regular": (["dm-sans.woff2"], 400, None, "normal"),
        "dm_sans_medium": (["dm-sans.woff2"], 500, None, "normal"),
        "dm_sans_semibold": (["dm-sans.woff2"], 600, None, "normal"),
        "dm_sans_bold": (["dm-sans.woff2"], 700, None, "normal"),
    },
    "DmMono": {
        "dm_mono_regular": (["dm-mono-400.woff2"], 400, None, "normal"),
        "dm_mono_medium": (["dm-mono-500.woff2"], 500, None, "normal"),
    },
    "PressStart": {
        "press_start": (["press-start-2p.woff2"], 400, None, "normal"),
    },
    "PixelifySans": {
        "pixelify_medium": (["tiny5.woff2", "pixelify-sans.woff2"], 500, None, "normal"),
        "pixelify_semibold": (["tiny5.woff2", "pixelify-sans.woff2"], 600, None, "normal"),
    },
}

# Text the check draws in every face besides each character alone: names, the
# mocks' headlines and numbers, and runs that kern.
SAMPLES = [
    "Arcade mode: leaderboards, world record, name entry", "playwheelsoff.com is live",
    "Read-only private repos via a GitHub App", "Redesign: one frame, four-section landing",
    "Alexandra Konstantinopoulou-Vasquez", "Jean-Baptiste Lemoine", "@tuxnotfound", "openstage.dev/tuxnotfound",
    "CHANGELOG · 2026.41", "Week 41 · Oct 5 – 11, 2026", "+11,976 −2,187 lines · 212 files", "74 commits in 3 projects",
    "AVAWAYTo Tr Ty Yo LT P. F, “quoted” ‘it’s’…", "Łódź Dvořák Zoë Ångström Ærø façade naïve",
    "0123456789 1,284 commits", "TOUCHED GRASS ×3 · NEXT · 1 BLOCK = 1 COMMIT",
]


def subset_fonts(sources):
    by_source = {spec[2]: name for name, spec in FILES.items() if spec[2]}
    for source in sources:
        name = by_source.get(Path(source).name)
        if not name:
            sys.exit(f"{source}: not a source in FILES")
        _family, _weight, _source, axes, unicodes = FILES[name]
        font = TTFont(source)
        font.flavor = "woff2"
        if unicodes is None:
            font.save(FONTS / name)
            print(FONTS / name)
            continue
        if axes:
            # Saved and read back before subsetting: the subsetter trips on the
            # instancer's half-loaded glyph variations otherwise.
            limited = BytesIO()
            instantiateVariableFont(font, axes).save(limited)
            font = TTFont(BytesIO(limited.getvalue()))
        options = subset.Options()
        options.flavor = "woff2"
        options.layout_features += ["tnum", "lnum", "pnum", "onum", "case"]
        subsetter = subset.Subsetter(options)
        subsetter.populate(unicodes=unicodes)
        subsetter.subset(font)
        font.save(FONTS / name)
        print(FONTS / name)


# Glyph substitutions the browser makes on its own (ccmp, which can draw one
# character as two glyphs) and those of the features a face turns on, such as
# tabular figures: each glyph to the glyphs drawn for it.
def substitutions(font, features):
    if "GSUB" not in font:
        return {}
    gsub = font["GSUB"].table
    mapping = {}
    for record in gsub.FeatureList.FeatureRecord:
        if record.FeatureTag != "ccmp" and f"'{record.FeatureTag}' 1" not in features:
            continue
        for index in record.Feature.LookupListIndex:
            for table in gsub.LookupList.Lookup[index].SubTable:
                found = getattr(getattr(table, "ExtSubTable", table), "mapping", {})
                mapping.update({glyph: out if isinstance(out, list) else [out] for glyph, out in found.items()})
    return mapping


def axes_of(font):
    return [axis.axisTag for axis in font["fvar"].axes] if "fvar" in font else []


# The axis values a face pins, as CSS: optical size and weight where its main
# file (the last it tries) has them.
def variation(files, weight, opsz):
    axes = axes_of(TTFont(FONTS / files[-1]))
    pins = []
    if "opsz" in axes and opsz:
        pins.append(f"'opsz' {opsz}")
    if "wght" in axes:
        pins.append(f"'wght' {weight}")
    return ", ".join(pins) or "normal"


# Thousandths of an em, rounded up so a sum never comes out narrower than the
# browser draws it. Each character comes from the first file that draws it, as
# in the browser: from its own glyph, or as its base letter with the accent
# marks the file has (the shaper composes it so, and marks take no room). A
# character no file draws comes from a fallback font, so it takes UNKNOWN.
def widths(files, weight, opsz, features):
    fonts = []
    for file in files:
        font = TTFont(FONTS / file)
        location = {tag: value for tag, value in (("wght", weight), ("opsz", opsz)) if tag in axes_of(font)}
        fonts.append((font.getBestCmap(), font.getGlyphSet(location=location), substitutions(font, features),
                      font["head"].unitsPerEm))
    out = []
    for char in CHARS:
        parts = [ord(c) for c in unicodedata.normalize("NFD", char)]
        width = UNKNOWN
        for cmap, glyphs, swap, units in fonts:
            code = ord(char) if ord(char) in cmap else parts[0] if all(part in cmap for part in parts) else None
            if code is not None:
                drawn = swap.get(cmap[code], [cmap[code]])
                width = math.ceil(sum(glyphs[glyph].width for glyph in drawn) * 1000 / units - 1e-9)
                break
        out.append(width)
    return out


def ruby_face(name, files, weight, opsz, features):
    families = ", ".join(f'"{FILES[file][0]}"' for file in files)
    numbers = textwrap.fill(", ".join(str(w) for w in widths(files, weight, opsz, features)), width=104,
                            initial_indent=" " * 10, subsequent_indent=" " * 10)
    return (f"      {name}: {{\n"
            f"        families: [ {families} ], weight: {weight}, variation: \"{variation(files, weight, opsz)}\",\n"
            f"        features: \"{features}\",\n"
            f"        widths: [\n{numbers}\n        ].freeze\n      }}.freeze")


def snake(name):
    return "".join(f"_{c.lower()}" if c.isupper() and i else c.lower() for i, c in enumerate(name))


def write_widths():
    for module, faces in FACES.items():
        files = " and ".join(dict.fromkeys(file for face in faces.values() for file in face[0]))
        families = " and ".join(dict.fromkeys(FILES[file][0] for face in faces.values() for file in face[0]))
        header = textwrap.fill(
            f"Advance widths of {families} for CardText, by face, in thousandths of an em: one per character of "
            f"CardText::LATIN. Generated by script/card_fonts.py from {files} in app/assets/fonts, so run it "
            "again rather than edit this file.", width=78, initial_indent="# ", subsequent_indent="# ")
        body = ",\n".join(ruby_face(name, *face) for name, face in faces.items())
        path = OUT / f"{snake(module)}.rb"
        path.write_text(f"{header}\nmodule CardText\n  module {module}\n    FACES = {{\n{body}\n    }}.freeze\n  end\nend\n")
        print(path)


# The page draws every sample and every character alone in every face, as SVG
# text set the way the card sets it, and prints Chrome's widths into the DOM.
def check_page(faces):
    rules = [f"@font-face{{font-family:'{family}';font-weight:{weight};src:url('{(FONTS / file).as_uri()}') format('woff2')}}"
             for file, (family, weight, *_rest) in FILES.items()]
    for name, (files, weight, opsz, features) in faces.items():
        stack = ",".join(f"'{FILES[file][0]}'" for file in files)
        rules.append(f".{name}{{font-family:{stack};font-weight:{weight};font-variation-settings:{variation(files, weight, opsz)};"
                     f"font-feature-settings:{features};font-size:100px}}")
    # Laying the text out first starts the font loads; widths are read once
    # every font is in.
    script = """
      const svg = document.querySelector("svg");
      const nodes = Object.entries(JOBS).map(([face, texts]) => [face, texts.map((text) => {
        const node = document.createElementNS("http://www.w3.org/2000/svg", "text");
        node.setAttribute("class", face);
        node.textContent = text;
        svg.appendChild(node);
        node.getComputedTextLength();
        return node;
      })]);
      document.fonts.ready.then(() => {
        const out = Object.fromEntries(nodes.map(([face, list]) => [face, list.map((node) => node.getComputedTextLength())]));
        document.body.setAttribute("data-widths", JSON.stringify(out));
      });"""
    jobs = {name: CHARS + SAMPLES for name in faces}
    return (f"<!doctype html><meta charset='utf-8'><style>{''.join(rules)}</style><body><svg width='10' height='10'></svg>"
            f"<script>const JOBS = {json.dumps(jobs)};{script}</script>")


def chrome_widths(page):
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / "check.html"
        path.write_text(page)
        dom = subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--allow-file-access-from-files",
                              "--virtual-time-budget=10000", "--dump-dom", path.as_uri()],
                             capture_output=True, text=True, check=True).stdout
    start = dom.index('data-widths="') + len('data-widths="')
    return json.loads(dom[start:dom.index('"', start)].replace("&quot;", '"').replace("&amp;", "&"))


# A character Chrome draws from a fallback font is left out: the tables count
# it as UNKNOWN on purpose.
def check():
    faces = {name: face for group in FACES.values() for name, face in group.items()}
    drawn = chrome_widths(check_page(faces))
    worst = 0
    for name, (files, weight, opsz, features) in faces.items():
        table = dict(zip(CHARS, widths(files, weight, opsz, features)))
        ratios = []
        for text, width in zip(CHARS + SAMPLES, drawn[name]):
            if any(table[char] == UNKNOWN for char in text if char in table) or not width:
                continue
            ratios.append((width / (sum(table.get(char, UNKNOWN) for char in text) / 10), text))
        high, low = max(ratios), min(ratios)
        worst = max(worst, high[0])
        print(f"{name:20} widest {high[0]:.4f} ({high[1][:32]!r})  narrowest {low[0]:.4f} ({low[1][:32]!r})")
    print(f"worst ratio, Chrome over the tables: {worst:.4f}")
    sys.exit(0 if worst <= 1.01 else 1)


if __name__ == "__main__":
    if sys.argv[1:2] == ["subset"] and len(sys.argv) > 2:
        subset_fonts(sys.argv[2:])
    elif sys.argv[1:] == ["widths"]:
        write_widths()
    elif sys.argv[1:] == ["check"]:
        check()
    else:
        sys.exit(__doc__)
