# The card a shared link shows on X and elsewhere: one for a builder's page,
# one for a project's, one for a blog post and one for every other page. Each
# is drawn as SVG (app/views/og_images) and sent as a PNG, through libvips, as
# the weekly email's chart is.
class OgImagesController < ApplicationController
  include DemoPage

  # The headline alone, kept as a file, for when drawing fails.
  FALLBACK = "/og-default.png".freeze

  rescue_from Vips::Error do |error|
    Rails.error.report(error)
    redirect_to FALLBACK
  end

  def site
    user = demo_user
    @section = demo_section(user) if user
    send_card "site"
  end

  def post
    @post = BlogPost.find(params[:slug])
    return head :not_found unless @post

    @chart = chart_of(@post) if @post.chart
    send_card "post"
  end

  def builder
    return head :not_found unless gather_card(slug: nil)

    send_card "builder"
  end

  def project
    return head :not_found unless gather_card(slug: params[:project])

    send_card "project"
  end

  private

  # False for a builder or project with no page to show.
  def gather_card(slug:)
    @user = User.active.find_by(username: params[:username])
    service = ShareCards::GatherService.new(user: @user, slug: slug)
    return false unless service.call

    @cards, @avatar = service.cards, service.avatar
    true
  end

  # The project a post is about, as its page shows it; none once it is gone,
  # or while its builder hides its commits, which its line is drawn from.
  def chart_of(post)
    username, slug = post.chart.split("/", 2)
    focus = Progress::FocusService.new(user: User.active.find_by(username: username), slug: slug)
    focus if focus.call && focus.card.commits_shown?
  end

  # The same drawing is turned into a PNG once a day at most.
  def send_card(template)
    svg = render_to_string(template: "og_images/#{template}", formats: [ :svg ], layout: "og_image")
    png = Rails.cache.fetch([ "share-card", Digest::SHA256.hexdigest(svg) ], expires_in: 1.day) do
      Vips::Image.svgload_buffer(svg).write_to_buffer(".png")
    end
    expires_in 1.hour, public: true
    send_data png, type: "image/png", disposition: "inline"
  end
end
