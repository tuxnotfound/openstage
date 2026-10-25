module SeoHelper
  SITE_NAME = "Openstage".freeze
  DEFAULT_TITLE = "Openstage: what you're building, project by project".freeze
  DEFAULT_DESCRIPTION = "Openstage keeps a public page of what you're building, project by project, " \
    "current from your GitHub commits. Free for indie builders.".freeze

  # Title shown in <title> and og:title. Pages set it with `content_for :title`.
  # Dynamic pages (e.g. profiles) should use the block form so user data is escaped.
  def page_title
    content_for?(:title) ? content_for(:title) : DEFAULT_TITLE
  end

  def meta_description
    content_for?(:meta_description) ? content_for(:meta_description) : DEFAULT_DESCRIPTION
  end

  # Defaults to the current path without query string, which collapses
  # paginated/filtered variants onto one canonical URL.
  def canonical_url
    content_for?(:canonical) ? content_for(:canonical) : "#{request.base_url}#{request.path}"
  end

  def og_type
    content_for?(:og_type) ? content_for(:og_type) : "website"
  end

  def og_image_for_page
    content_for?(:og_image) ? content_for(:og_image) : share_card(og_site_url)
  end

  # A share card's address (OgImagesController). X and others keep the image
  # they fetched for an address; a new version makes them fetch the new look.
  SHARE_CARD_VERSION = 4

  def share_card(url)
    "#{url}?v=#{SHARE_CARD_VERSION}"
  end

  # Site-wide Organization + WebSite graph, rendered on every page so search
  # engines and AI crawlers can resolve the brand consistently.
  def site_structured_data
    base = request.base_url
    {
      "@context" => "https://schema.org",
      "@graph" => [
        {
          "@type" => "Organization",
          "@id" => "#{base}/#organization",
          "name" => SITE_NAME,
          "url" => "#{base}/",
          "logo" => "#{base}/icon-512.png",
          "description" => DEFAULT_DESCRIPTION,
          "sameAs" => [ "https://github.com/tuxnotfound" ]
        },
        {
          "@type" => "WebSite",
          "@id" => "#{base}/#website",
          "name" => SITE_NAME,
          "url" => "#{base}/",
          "publisher" => { "@id" => "#{base}/#organization" }
        }
      ]
    }
  end
end
