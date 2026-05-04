require "mini_magick"
require "open-uri"

# Generates a 1200×630 OG card styled to match the website:
# white background, gray-900 text, gray-200 dividers, gray-400 muted labels.
class OgImageGenerator
  W = 1200
  H = 630

  # Matches Tailwind classes used in the app
  BG         = "#ffffff"   # white
  PAGE_BG    = "#f9fafb"   # gray-50 (subtle outer fill)
  BORDER     = "#e5e7eb"   # gray-200
  TEXT_DARK  = "#111827"   # gray-900
  TEXT_MID   = "#6b7280"   # gray-500
  TEXT_MUTED = "#9ca3af"   # gray-400
  RING       = "#f3f4f6"   # gray-100 (avatar ring)
  BRAND      = "#9ca3af"   # gray-400

  # Card insets
  CX = 44   # card left/right inset
  CY = 32   # card top/bottom inset  → card: y=32 to y=598
  CR = 20   # corner radius

  # Avatar — smaller so top text has a safe top margin
  AV_X = 90    # avatar centre x
  AV_Y = 178   # avatar centre y
  AV_R = 56    # avatar radius (was 72)

  # Text column start
  TX = 196

  def self.call(user, entries_count:, repos_count:, milestones_count:, recent_commits_count:, streak_count:)
    new(user, entries_count, repos_count, milestones_count, recent_commits_count, streak_count).generate
  end

  def initialize(user, entries_count, repos_count, milestones_count, recent_commits_count, streak_count)
    @user                 = user
    @entries_count        = entries_count
    @repos_count          = repos_count
    @milestones_count     = milestones_count
    @recent_commits_count = recent_commits_count
    @streak_count         = streak_count
    @tempfiles            = []
  end

  def generate
    out = tempfile(".png")

    MiniMagick.convert do |c|
      # Page background
      c.size "#{W}x#{H}"
      c.xc PAGE_BG

      # White card
      c.fill BG
      c.stroke BORDER
      c.strokewidth "2"
      c.draw "roundrectangle #{CX},#{CY} #{W - CX},#{H - CY} #{CR},#{CR}"

      # Avatar (circle-cropped)
      c.stroke "none"
      draw_avatar(c)

      # Avatar ring
      c.fill "none"
      c.stroke RING
      c.strokewidth "5"
      c.draw "circle #{AV_X},#{AV_Y} #{AV_X},#{AV_Y - AV_R - 3}"

      # Reset stroke before text
      c.stroke "none"
      c.gravity "NorthWest"

      # Name — baseline y=108 → cap-top ≈ y=64 (32px inside card: safe on Linux)
      c.fill TEXT_DARK
      c.font font_bold
      c.pointsize "52"
      c.annotate "+#{TX}+108", esc(@user.display_name.to_s.truncate(22))

      # @handle  ·  github
      c.fill TEXT_MUTED
      c.font font_mono
      c.pointsize "20"
      c.annotate "+#{TX}+168", esc("@#{@user.username}  ·  github.com/#{@user.github_username}")

      sub_y = 200
      if @user.building_since.present?
        c.fill TEXT_MID
        c.font font_regular
        c.pointsize "18"
        c.annotate "+#{TX}+#{sub_y}", "Building since #{@user.building_since.strftime('%B %Y')}"
        sub_y += 30
      end

      if @user.bio.present?
        c.fill TEXT_MID
        c.font font_regular
        c.pointsize "19"
        c.annotate "+#{TX}+#{sub_y}", esc(@user.bio.truncate(66))
      end

      # Horizontal divider — pulled up to y=262 (compact gap after bio)
      c.fill BORDER
      c.draw "rectangle #{CX + 20},262 #{W - CX - 20},264"

      # Stats (4 columns)
      draw_stats(c)

      # branding — bottom right inside card
      c.gravity "SouthEast"
      c.fill TEXT_MUTED
      c.font font_regular
      c.pointsize "19"
      c.annotate "+#{CX + 20}+#{CY + 20}", "openstage.dev"

      c << out.path
    end

    File.binread(out.path)
  ensure
    @tempfiles.each { |f| f.close; f.unlink rescue nil }
  end

  private

  # 4 evenly spaced stat columns
  COL_START = 74
  COL_W     = 268

  def draw_stats(c)
    labels = %w[ENTRIES COMMITS STREAK MILESTONES]
    values = [@entries_count, @recent_commits_count, @streak_count, @milestones_count]

    labels.each_with_index do |label, i|
      x = COL_START + (i * COL_W)

      # Vertical separator (not before first)
      if i > 0
        c.fill BORDER
        c.draw "rectangle #{x - 1},270 #{x + 1},#{H - CY - 40}"
      end

      # Stat number — 60pt (was 72), baseline y=352 → cap-top ≈ y=301 (safe)
      c.gravity "NorthWest"
      c.fill TEXT_DARK
      c.font font_bold
      c.pointsize "60"
      c.annotate "+#{x + 16}+340", values[i].to_s

      # Label — uppercase, gray-400, tight below number
      c.fill TEXT_MUTED
      c.font font_regular
      c.pointsize "15"
      c.annotate "+#{x + 18}+414", label
    end
  end

  def draw_avatar(c)
    path = download_avatar
    return unless path

    size = AV_R * 2

    c << "("
    c << path
    c.resize "#{size}x#{size}^"
    c.gravity "Center"
    c.extent "#{size}x#{size}"
    c << "("
    c << "+clone"
    c.alpha "extract"
    c.draw "fill black polygon 0,0 0,#{size} #{size / 2},#{size} fill white circle #{size / 2},#{size / 2} #{size / 2},0"
    c << "("
    c << "+clone"
    c.flip
    c << ")"
    c.compose "Multiply"
    c.composite
    c << "("
    c << "+clone"
    c.flop
    c << ")"
    c.compose "Multiply"
    c.composite
    c << ")"
    c.alpha "off"
    c.compose "CopyOpacity"
    c.composite
    c << ")"
    c.gravity "NorthWest"
    c.geometry "+#{AV_X - AV_R}+#{AV_Y - AV_R}"
    c.compose "Over"
    c.composite
  end

  def download_avatar
    url = @user.avatar_url
    return nil if url.blank? || !url.start_with?("https://")

    tmp = tempfile(".jpg")
    URI.open(url, read_timeout: 3) { |io| tmp.write(io.read) }
    tmp.flush
    tmp.path
  rescue => e
    Rails.logger.warn("[OgImageGenerator] Avatar download failed: #{e.message}")
    nil
  end

  def font_regular
    @font_regular ||= detect_font(%w[Liberation-Sans FreeSans DejaVu-Sans Helvetica Arial])
  end

  def font_bold
    @font_bold ||= detect_font(%w[Liberation-Sans-Bold FreeSans-Bold DejaVu-Sans-Bold Helvetica-Bold Arial-Bold])
  end

  def font_mono
    @font_mono ||= detect_font(%w[Liberation-Mono FreeMono DejaVu-Sans-Mono Courier-New Courier])
  end

  def detect_font(candidates)
    @available_fonts ||= `convert -list font 2>/dev/null`
    candidates.find { |f| @available_fonts.include?(f) } || "Helvetica"
  end

  def esc(text)
    text.to_s.gsub("%", "%%")
  end

  def tempfile(ext)
    file = Tempfile.new(["og_", ext])
    file.binmode
    @tempfiles << file
    file
  end
end

