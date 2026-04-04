require "mini_magick"
require "open-uri"

class OgImageGenerator
  CARD_W      = 1200
  CARD_H      = 630
  AVATAR_SIZE = 160
  AVATAR_X    = 72
  AVATAR_Y    = 188

  def self.call(user, entries_count:, repos_count:, milestones_count:)
    new(user, entries_count, repos_count, milestones_count).generate
  end

  def initialize(user, entries_count, repos_count, milestones_count)
    @user             = user
    @entries_count    = entries_count
    @repos_count      = repos_count
    @milestones_count = milestones_count
    @tempfiles        = []
  end

  def generate
    out = tempfile(".png")

    MiniMagick::Tool::Convert.new do |c|
      background(c)
      avatar(c)
      accent_bar(c)
      name_text(c)
      username_text(c)
      building_since_text(c) if @user.building_since.present?
      bio_text(c)             if @user.bio.present?
      stats_text(c)
      branding_text(c)
      c << out.path
    end

    File.binread(out.path)
  ensure
    @tempfiles.each { |f| f.close; f.unlink rescue nil }
  end

  private

  # ── Canvas ────────────────────────────────────────────────────────────

  def background(c)
    c.size "#{CARD_W}x#{CARD_H}"
    c.xc "#0f172a"
  end

  # ── Avatar ────────────────────────────────────────────────────────────

  def avatar(c)
    path = download_avatar
    return unless path

    c << "("
    c << path
    c.resize "#{AVATAR_SIZE}x#{AVATAR_SIZE}^"
    c.gravity "Center"
    c.extent "#{AVATAR_SIZE}x#{AVATAR_SIZE}"
    # Circular mask via polygon + flip/flop technique
    c << "("
    c << "+clone"
    c.alpha "extract"
    c.draw "fill black polygon 0,0 0,#{AVATAR_SIZE} #{AVATAR_SIZE / 2},#{AVATAR_SIZE} " \
           "fill white circle #{AVATAR_SIZE / 2},#{AVATAR_SIZE / 2} #{AVATAR_SIZE / 2},0"
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

  # ── Text layers ───────────────────────────────────────────────────────

  def accent_bar(c)
    c.fill "#6366f1"
    c.draw "rectangle 0,0 #{CARD_W},3"
  end

  def name_text(c)
    c.fill "#f8fafc"
    c.font "Liberation-Sans-Bold"
    c.pointsize "48"
    c.gravity "NorthWest"
    c.annotate "+276+216", escape(@user.display_name.truncate(26))
  end

  def username_text(c)
    c.fill "#64748b"
    c.font "Liberation-Mono"
    c.pointsize "28"
    c.gravity "NorthWest"
    c.annotate "+278+278", "@#{escape(@user.username)}"
  end

  def building_since_text(c)
    c.fill "#94a3b8"
    c.font "Liberation-Sans"
    c.pointsize "22"
    c.gravity "NorthWest"
    c.annotate "+278+322", "Building since #{@user.building_since.strftime('%B %Y')}"
  end

  def bio_text(c)
    c.fill "#94a3b8"
    c.font "Liberation-Sans"
    c.pointsize "22"
    c.gravity "NorthWest"
    y = @user.building_since.present? ? 360 : 322
    c.annotate "+278+#{y}", escape(@user.bio.truncate(72))
  end

  def stats_text(c)
    c.fill "#475569"
    c.font "Liberation-Sans"
    c.pointsize "24"
    c.gravity "NorthWest"
    c.annotate "+278+#{stats_y}", "#{@entries_count} entries · #{@repos_count} repos · #{@milestones_count} milestones"
  end

  def branding_text(c)
    c.gravity "SouthEast"
    c.fill "#334155"
    c.font "Liberation-Sans"
    c.pointsize "20"
    c.annotate "+72+38", "openstage.dev"
  end

  # ── Helpers ───────────────────────────────────────────────────────────

  def stats_y
    has_since = @user.building_since.present?
    has_bio   = @user.bio.present?
    if has_since && has_bio then 420
    elsif has_since || has_bio then 378
    else 334
    end
  end

  def escape(text)
    text.to_s.gsub("%", "%%")
  end

  def tempfile(ext)
    f = Tempfile.new(["og_", ext])
    f.binmode
    @tempfiles << f
    f
  end
end
