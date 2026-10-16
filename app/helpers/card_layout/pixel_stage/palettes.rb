module CardLayout
  class PixelStage
    # The skies, by theme and by the hour the builder commits most, and the
    # grounds they stand on, from the mock as they are.
    module Palettes
      SKIES = {
        "dark" => {
          night: {
            bands: [ "#050816", "#070B1F", "#0A1029", "#0D1633", "#111C3D", "#152347", "#1A2A52", "#20325C", "#273B66" ],
            far: "#1A2550", near: "#111A3A", stars: "#FFF6D8", moon: "#F4E9C8", ground: "night"
          },
          dusk: {
            bands: [ "#160F33", "#1E1340", "#29184B", "#371D55", "#4A225D", "#612865", "#7D2F69", "#9C386B", "#BE4569", "#DE5A62", "#F57A5C", "#FF9E5E" ],
            far: "#3B1F52", near: "#281540", sun: "#FFC46B", sun_in: "#FFE3A1", cloud: "#F59A86", ground: "dusk"
          },
          day: {
            bands: [ "#0B2350", "#0E2C61", "#123672", "#164183", "#1B4C93", "#2058A2", "#2764B0", "#3071BD", "#3A7EC8", "#4A8DD2" ],
            far: "#1B3B74", near: "#132C5C", sun: "#FFE9A6", sun_in: "#FFF6D6", cloud: "#7FA3D8", ground: "day"
          },
          dawn: {
            bands: [ "#0E1430", "#151B3E", "#1F2350", "#2C2A5C", "#3E3166", "#553A6E", "#714575", "#92537A", "#B5647C", "#D77B7C", "#F0987A" ],
            far: "#3A3160", near: "#272248", sun: "#FFD08A", sun_in: "#FFE9BE", cloud: "#E39A93", ground: "dusk"
          }
        }.freeze,
        "light" => {
          night: {
            bands: [ "#3A4A8C", "#45559A", "#5262A6", "#6170B1", "#727FBB", "#8590C4", "#9AA2CC", "#B0B5D4", "#C7C9DC" ],
            far: "#6874B0", near: "#525E9C", stars: "#FFF6D8", moon: "#FFF8DE", ground: "light_night"
          },
          dusk: {
            bands: [ "#5B8ED6", "#6C9ADB", "#7FA7DF", "#93B3E2", "#A9BEE2", "#C0C8DF", "#D8D0D8", "#EED4C8", "#FDD3B0", "#FFC995" ],
            far: "#9CA6D2", near: "#7F8BC2", sun: "#FFF1C9", sun_in: "#FFFBEA", cloud: "#FFFFFF", ground: "light"
          },
          day: {
            bands: [ "#4D9FF2", "#5EAAF4", "#70B5F6", "#83C0F7", "#97CBF9", "#ACD6FA", "#C2E1FB", "#D8ECFC" ],
            far: "#9FC3EA", near: "#84B0E0", sun: "#FFF4C2", sun_in: "#FFFCEB", cloud: "#FFFFFF", ground: "light"
          },
          dawn: {
            bands: [ "#7DA8E8", "#91B4EA", "#A6C0EA", "#BCCAE8", "#D2D2E4", "#E6D6DC", "#F6D8D0", "#FFD8C0" ],
            far: "#AAB3DA", near: "#919CCB", sun: "#FFF0C4", sun_in: "#FFFBEA", cloud: "#FFFFFF", ground: "light"
          }
        }.freeze
      }.freeze
      GROUND = {
        night: { hi: "#3F8F4B", grass: "#2C6B37", dirt: "#352116", s1: "#28180F", s2: "#45291B", tuft: "#4FA35A", label: "#FFE7C2", mute: "#E2A98F" },
        dusk: { hi: "#5AA84E", grass: "#3E7E3B", dirt: "#4A2B1D", s1: "#3A2116", s2: "#5E3725", tuft: "#6CBF5C", label: "#FFE7C2", mute: "#E2A98F" },
        day: { hi: "#5DB653", grass: "#3E8A3B", dirt: "#4A2D1E", s1: "#3A2217", s2: "#5E3826", tuft: "#72C863", label: "#FFE7C2", mute: "#E2A98F" },
        light: { hi: "#86D86E", grass: "#58B54E", dirt: "#6E4A2E", s1: "#5E3E25", s2: "#7E5636", tuft: "#9BE281", label: "#FFF1D6", mute: "#F3D2B4" },
        light_night: { hi: "#86D86E", grass: "#58B54E", dirt: "#6E4A2E", s1: "#5E3E25", s2: "#7E5636", tuft: "#9BE281", label: "#FFF1D6", mute: "#F3D2B4" }
      }.freeze
    end
  end
end
