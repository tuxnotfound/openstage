# libvips decodes many formats, and some of its loaders are not fuzzed against hostile files.
# Block those, as Active Storage would, but keep the SVG loader: every SVG it reads is one the
# app wrote itself (the weekly email's chart, the share cards).
require "vips"

Vips.block_untrusted(true)
Vips.block("VipsForeignLoadSvg", false)
