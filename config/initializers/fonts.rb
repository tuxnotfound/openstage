# librsvg finds fonts through fontconfig, which reads FONTCONFIG_FILE the first
# time it draws text, so this only has to come before any request. On macOS,
# Pango asks Core Text instead unless told to use fontconfig.
ENV["FONTCONFIG_FILE"] ||= Rails.root.join("config/fonts.conf").to_s
ENV["PANGOCAIRO_BACKEND"] ||= "fc"
