module SeoHelper
  SITE_NAME = "Openstage".freeze
  DEFAULT_TITLE = "Openstage — Your build, in public. One link.".freeze
  DEFAULT_DESCRIPTION = "Openstage turns your GitHub commits, milestones, and notes into one " \
    "automatically-updated build-in-public timeline. Claim your public builder profile and share a single link.".freeze

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
    content_for?(:og_image) ? content_for(:og_image) : "#{request.base_url}/og-default.png"
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
