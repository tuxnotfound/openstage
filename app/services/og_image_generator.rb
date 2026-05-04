require "mini_magick"
require "open-uri"

class OgImageGenerator
  CARD_W      = 1200
  CARD_H      = 630
  AVATAR_SIZE = 132
  AVATAR_X    = 84
  AVATAR_Y    = 96

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
      background(c)
      background_glow(c)
      panel(c)
      avatar(c)
      accent_orb(c)
      eyebrow_text(c)
      name_text(c)
      username_text(c)
      building_since_text(c) if @user.building_since.present?
      bio_text(c) if @user.bio.present?
      stat_cards(c)
      footer_text(c)
      branding_text(c)
      c << out.path
    end

    File.binread(out.path)
  ensure
    @tempfiles.each { |file| file.close; file.unlink rescue nil }
  end

  private

  def background(c)
    c.size "#{CARD_W}x#{CARD_H}"
    c.xc "#0b1120"
  end

  def background_glow(c)
    c.fill "#15254a"
    c.draw "circle 1060,110 1180,110"
    c.fill "#0f766e"
    c.draw "circle 180,620 340,620"
  end

  def panel(c)
    c.fill "#111c34"
    c.stroke "#334155"
    c.strokewidth 2
    c.draw "roundrectangle 46,42 1154,588 28,28"
  end

  def avatar(c)
    path = download_avatar
    return unless path

    c << "("
    c << path
    c.resize "#{AVATAR_SIZE}x#{AVATAR_SIZE}^"
    c.gravity "Center"
    c.extent "#{AVATAR_SIZE}x#{AVATAR_SIZE}"
    c << "("
    c << "+clone"
    c.alpha "extract"
    c.draw "fill black polygon 0,0 0,#{AVATAR_SIZE} #{AVATAR_SIZE / 2},#{AVATAR_SIZE} fill white circle #{AVATAR_SIZE / 2},#{AVATAR_SIZE / 2} #{AVATAR_SIZE / 2},0"
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
    c.geometry "+#{AVATAR_X}+#{AVATAR_Y}"
    c.compose "Over"
    c.composite

    c.fill "none"
    c.stroke "#f59e0b"
    c.strokewidth 4
    c.draw "circle #{AVATAR_X + (AVATAR_SIZE / 2)},#{AVATAR_Y + (AVATAR_SIZE / 2)} #{AVATAR_X + (AVATAR_SIZE / 2)},#{AVATAR_Y + 4}"
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

  def accent_orb(c)
    c.fill "#f97316"
    c.draw "circle 1080,132 1110,132"
  end

  def eyebrow_text(c)
    c.fill "#f59e0b"
    c.font "Liberation-Sans-Bold"
    c.pointsize "20"
    c.gravity "NorthWest"
    c.annotate "+276+116", "BUILDING IN PUBLIC"
  end

  def name_text(c)
    c.fill "#f8fafc"
    c.font "Liberation-Sans-Bold"
    c.pointsize "54"
    c.gravity "NorthWest"
    c.annotate "+276+182", escape(@user.display_name.truncate(24))
  end

  def username_text(c)
    c.fill "#94a3b8"
    c.font "Liberation-Mono"
    c.pointsize "26"
    c.gravity "NorthWest"
    c.annotate "+278+228", "@#{escape(@user.username)}  ·  github.com/#{escape(@user.github_username)}"
  end

  def building_since_text(c)
    c.fill "#94a3b8"
    c.font "Liberation-Sans"
    c.pointsize "22"
    c.gravity "NorthWest"
    c.annotate "+278+270", "Building since #{@user.building_since.strftime('%B %Y')}"
  end

  def bio_text(c)
    c.fill "#cbd5e1"
    c.font "Liberation-Sans"
    c.pointsize "22"
    c.gravity "NorthWest"
    y = @user.building_since.present? ? 314 : 270
    c.annotate "+278+#{y}", escape(@user.bio.truncate(74))
  end

  def stat_cards(c)
    card_specs.each do |card|
      draw_stat_card(c, **card)
    end
  end

  def draw_stat_card(c, x:, y:, label:, value:, accent:)
    c.fill "#17233d"
    c.stroke accent
    c.strokewidth 2
    c.draw "roundrectangle #{x},#{y} #{x + 228},#{y + 124} 20,20"

    c.fill accent
    c.font "Liberation-Sans-Bold"
    c.pointsize "18"
    c.gravity "NorthWest"
    c.annotate "+#{x + 20}+#{y + 34}", label.upcase

    c.fill "#f8fafc"
    c.font "Liberation-Sans-Bold"
    c.pointsize "42"
    c.annotate "+#{x + 20}+#{y + 86}", value.to_s
  end

  def footer_text(c)
    c.fill "#94a3b8"
    c.font "Liberation-Sans"
    c.pointsize "24"
    c.gravity "NorthWest"
    c.annotate "+84+534", "#{@repos_count} repos synced · #{@milestones_count} milestones shipped"
  end

  def branding_text(c)
    c.gravity "SouthEast"
    c.fill "#f8fafc"
    c.font "Liberation-Sans-Bold"
    c.pointsize "22"
    c.annotate "+72+40", "openstage.dev"
  end

  def card_specs
    [
      { x: 84, y: 374, label: "Recent commits", value: @recent_commits_count, accent: "#38bdf8" },
      { x: 332, y: 374, label: "Entries", value: @entries_count, accent: "#f59e0b" },
      { x: 580, y: 374, label: "Streak", value: @streak_count, accent: "#34d399" },
      { x: 828, y: 374, label: "Milestones", value: @milestones_count, accent: "#f97316" }
    ]
  end

  def escape(text)
    text.to_s.gsub("%", "%%")
  end

  def tempfile(ext)
    file = Tempfile.new(["og_", ext])
    file.binmode
    @tempfiles << file
    file
  end
end
