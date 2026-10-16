module CardLayout
  class PixelStage
    # The scene's bitmaps and palettes, copied from doc/week_cards/mocks/
    # pixel_stage.dc.html as they are: data, not design to redo. One letter per
    # cell; a dot is empty.
    module Sprites
      CAMPFIRE = [
        "....y....",
        "...yy....",
        "...yoy...",
        "..yoooy..",
        "..oorro..",
        ".oorrroo.",
        "..orrro..",
        "lLlLlLlLl",
        ".lLlLlLl."
      ].freeze
      SMALLFIRE = [ "...y...", "..yoy..", "..oro..", ".orrro.", "lLlLlLl" ].freeze
      TENT = [
        "......t......",
        ".....ttT.....",
        "....tttTT....",
        "...ttttdTT...",
        "..tttttddTT..",
        ".ttttttddTTT.",
        "tttttttddTTTT"
      ].freeze
      CLOUD = [ "......cccc......", "...cccccccccc...", "..cccccccccccc..", "cccccccccccccccc", ".cccccccccccccc." ].freeze
      PENNANT = [
        "fffffffffff",
        "fffffwfffff",
        "ffffwwwfff.",
        "fffwwwwwf..",
        "ffffwwwfff.",
        "ffffwfwffff",
        "FFFFFFFFFFF"
      ].freeze
      TUFT = [ ".g.g.", "g.ggg" ].freeze
      WAVE = [ "..o..", ".o...", "o..i.", "o.i..", "o.i..", "o..i.", ".o...", "..o.." ].freeze
      PINE = [ "..t..", "..t..", ".ttt.", ".ttt.", "ttttt", "ttttt" ].freeze
      PINE_S = [ ".t.", ".t.", "ttt", "ttt" ].freeze
      ICON_BLOCK = [ "hhhhhhhh", "hbbbbbbs", "hbbbbbbs", "hbbbbbbs", "hbbbbbbs", "hbbbbbbs", "hbbbbbbs", "ssssssss" ].freeze
      ICON_FLAG = [ "y.......", "pffffff.", "pfffff..", "pffffff.", "pFFFFF..", "p.......", "p.......", "pp......" ].freeze
      ICON_MAST = [ "...rr...", ".a.rr.a.", "a..pp..a", ".a.pp.a.", "...pp...", "...pp...", "...pp...", "..pppp.." ].freeze
      STAND = [
        ".....hqqqqqqh.....",
        "....qHHHhhhhhq....",
        "...qHHhhhhhhhhq...",
        "gg.qHhhhhhhhhhq...",
        "gGqhhvvvvvvvvhsq..",
        "hhqhaWVVaaWVVasq..",
        "hhqhaVVVaaVVVasq..",
        "hhqhhvvvvvvvvhsq..",
        "Hh.hhhSSSSSShhs...",
        "Hh.hhhhhhhhhhss...",
        "Hh..hhhhhhhhss....",
        "Hh...ssssssss.....",
        "Hhooooooooooooo...",
        "HhhHSSSSSSSShhhhgg",
        ".HHhhhwhhwhhhhssgG",
        "..Hhhhwhhwhhhsbb..",
        "..Hhhpppppphhsbb..",
        "..Hsssssssssssbb..",
        "...jjjj..jjjJ.....",
        "...jjjJ..jjjJ.....",
        "..kkkkK..kkkkK...."
      ].freeze
      IDLE = [
        ".....hqqqqqqh....",
        "....qHHHhhhhhq...",
        "...qHHhhhhhhhhq..",
        "gg.qHhhhhhhhhhq..",
        "gGqhhvvvvvvvvhsq.",
        "hhqhaWVVaaWVVasq.",
        "hhqhaVVVaaVVVasq.",
        "hhqhhvvvvvvvvhsq.",
        "Hh.hhhSSSSSShhs..",
        "Hh.hhhhhhhhhhss..",
        "Hh..hhhhhhhhss...",
        "Hh...ssssssss....",
        "Hhooooooooooooo..",
        "HhhHSSSSSSSShhhh.",
        ".HHhhhwhhwhhhshh.",
        "..Hhhhwhhwhhhshs.",
        "..Hhhpppppphhsgg.",
        "..Hsssssssssss...",
        "...jjjj..jjjJ....",
        "...jjjJ..jjjJ....",
        "..kkkkK..kkkkK..."
      ].freeze
      SIT = [
        "....hqqqqqqh.......",
        "...qHHHhhhhhq......",
        "..qHHhhhhhhhhq.....",
        "..qHhhhhhhhhhq.....",
        ".qhhvvvvvvvvhsq....",
        ".qhaWVVaaWVVasq....",
        ".qhaVVVaaVVVasq....",
        ".qhhvvvvvvvvhsq....",
        "..hhhSSSSSShhs.....",
        "..hhhhhhhhhhss.....",
        "...hhhhhhhhss......",
        "....ssssssss.......",
        "..oooooooooooo.....",
        "..HHSSSSSSSShh.....",
        ".hHhhwhhwhhhhhhgg..",
        ".hHhhwhhwhhhhshgG..",
        ".gHhpppppphhs......",
        ".gjjjjjjjjjjj......",
        "..jJjjjjjjJjJ......",
        "...jjj...jjj.......",
        "..kkkkK..kkkkK....."
      ].freeze
      LOG = [ "eLLLLLLLLLLLLLLLLLe", "ellllllllllllllllE", "eLlllLllllllLlllle", "eLLLLLLLLLLLLLLLLe" ].freeze
      FIRE = { "y" => "#FFE27A", "o" => "#FFB020", "r" => "#FF5A1F", "l" => "#7A4A2A", "L" => "#5A3320" }.freeze
    end
  end
end
