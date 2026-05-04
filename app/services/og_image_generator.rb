require "mini_magick"
require "open-uri"

class OgImageGenerator
  CARD_W      = 1200
  CARD_H      = 630
  AVATAR_SIZE = 136
  AVATAR_X    = 84
  AVATAR_Y    = 112

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
      card(c)
      card_top_rule(c)
      avatar(c)
      eyebrow_text(c)
      name_text(c)
      username_text(c)
      building_since_text(c) if @user.building_since.present?
      bio_text(c) if @user.bio.present?
      stat_blocks(c)
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
    c.xc "#f3f4f6"
  end

  def card(c)
    c.fill "#ffffff"
    c.stroke "#e5e7eb"
    c.strokewidth 2
    c.draw "roundrectangle 40,36 1160,594 24,24"
  end

  def card_top_rule(c)
    c.fill "#111827"
    c.draw "rectangle 64,76 1136,80"
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
    c.stroke "#d1d5db"
    c.strokewidth 3
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

  def eyebrow_text(c)
    c.fill "#6b7280"
    c.font "Liberation-Sans"
    c.pointsize "19"
    c.gravity "NorthWest"
    c.annotate "+280+118", "BUILDING IN PUBLIC"
  end

  def name_text(c)
    c.fill "#111827"
    c.font "Liberation-Sans-Bold"
    c.pointsize "56"
    c.gravity "NorthWest"
    c.annotate "+276+186", escape(@user.display_name.truncate(24))
  end

  def username_text(c)
    c.fill "#6b7280"
    c.font "Liberation-Mono"
    c.pointsize "24"
    c.gravity "NorthWest"
    c.annotate "+278+232", "@#{escape(@user.username)}  ·  github.com/#{escape(@user.github_username)}"
  end

  def building_since_text(c)
    c.fill "#6b7280"
    c.font "Liberation-Sans"
    c.pointsize "21"
    c.gravity "NorthWest"
    c.annotate "+278+272", "Building since #{@user.building_since.strftime('%B %Y')}"
  end

  def bio_text(c)
    c.fill "#374151"
    c.font "Liberation-Sans"
    c.pointsize "22"
    c.gravity "NorthWest"
    y = @user.building_since.present? ? 316 : 272
    c.annotate "+278+#{y}", escape(@user.bio.truncate(74))
  end

  def stat_blocks(c)
    card_specs.each do |card|
      draw_stat_card(c, **card)
    end
  end

  def draw_stat_card(c, x:, y:, label:, value:)
    c.fill "#f9fafb"
    c.stroke "#e5e7eb"
    c.strokewidth 2
    c.draw "roundrectangle #{x},#{y} #{x + 228},#{y + 124} 16,16"

    c.fill "#6b7280"
    c.font "Liberation-Sans"
    c.pointsize "18"
    c.gravity "NorthWest"
    c.annotate "+#{x + 20}+#{y + 34}", label.upcase

    c.fill "#111827"
    c.font "Liberation-Sans-Bold"
    c.pointsize "44"
    c.annotate "+#{x + 20}+#{y + 86}", value.to_s
  end

  def footer_text(c)
    c.fill "#6b7280"
    c.font "Liberation-Sans"
    c.pointsize "22"
    c.gravity "NorthWest"
    c.annotate "+84+538", "#{@repos_count} repos synced · #{@milestones_count} milestones"
  end

  def branding_text(c)
    c.gravity "SouthEast"
    c.fill "#111827"
    c.font "Liberation-Sans"
    c.pointsize "20"
    c.annotate "+72+40", "openstage.dev"
  end

  def card_specs
    [
      { x: 84, y: 382, label: "Recent commits", value: @recent_commits_count },
      { x: 332, y: 382, label: "Entries", value: @entries_count },
      { x: 580, y: 382, label: "Streak", value: @streak_count },
      { x: 828, y: 382, label: "Milestones", value: @milestones_count }
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
