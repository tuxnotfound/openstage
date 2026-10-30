module SiteVisits
  # One page view sent by Openstage's script, as much of it as the day's
  # counts keep (SiteVisitCount): its page's path, and for a visitor's first
  # view of the day the site they came from, the ref tag they followed and
  # their country. Never a query string, a whole referrer, or a part of a
  # path that looks like an email, an id or a secret.
  class PageView
    MAX_PATH = 200
    MAX_TAG = 64
    # A host as it names a site, at most as long as DNS allows.
    HOST = /\A[a-z0-9_-]+(\.[a-z0-9_-]+)*\z/
    MAX_HOST = 253
    UUID = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/
    TOKEN = /\A[A-Za-z0-9_-]{24,}\z/

    # url: the page viewed, on the project's website; referrer: the page's
    # referrer, which the script sends with a page load's first view only,
    # nil on the others and from an older script; country: Cloudflare's
    # CF-IPCountry; site_host: the project's website's host.
    def initialize(url:, referrer:, country:, site_host:)
      @url = url
      @referrer = referrer
      @country = country
      @site_host = site_host
    end

    # Whether an address is on the project's website: www. and the bare
    # domain are one site.
    def on_site?(address)
      host = host_of(address)
      host.present? && @site_host.present? && host.delete_prefix("www.") == @site_host.delete_prefix("www.")
    end

    # What it adds to the day's counts, by kind: its page always; on its
    # visitor's first view of the day their country and, when the script
    # sent a referrer, their source and ref tag.
    def counts(first:)
      return { "page" => page } unless first

      counts = { "page" => page, "source" => source, "country" => country }
      counts["ref"] = ref_tag unless @referrer.nil?
      counts.compact
    end

    # The path alone, its trailing slash dropped, a part that looks personal
    # or secret as "*".
    def page
      path = URI(@url).path.split("/").map { |part| personal?(part) ? "*" : part }.join("/")
      path.presence&.first(MAX_PATH) || "/"
    end

    # The referrer's host, www. dropped; DIRECT for an empty referrer; nil
    # without a referrer, for one on the project's own website, or for one
    # with no host to name.
    def source
      return if @referrer.nil?
      return SiteVisitCount::DIRECT if @referrer.blank?

      host = host_of(@referrer)&.delete_prefix("www.")
      host if host&.match?(HOST) && host.length <= MAX_HOST && !on_site?(@referrer)
    end

    # The page's ref or utm_source tag, the first given, in letters, digits,
    # ".", "-" and "_" alone.
    def ref_tag
      params = URI.decode_www_form(URI(@url).query.to_s)
      tags = %w[ref utm_source].flat_map { |key| params.filter_map { |name, value| value if name == key } }
      tags.map { |tag| tag.scrub("").downcase.gsub(/[^a-z0-9._-]/, "").first(MAX_TAG) }.find(&:present?)
    end

    # Two letters; Cloudflare's XX (unknown) and T1 (Tor) name no country.
    def country
      code = @country.to_s.strip.upcase
      code if code.match?(/\A[A-Z]{2}\z/) && code != "XX"
    end

    private

    # An email, a UUID, or a long token mixing letters and digits.
    def personal?(part)
      return true if part.include?("@") || part.match?(/%40/i) || part.match?(UUID)

      part.match?(TOKEN) && part.match?(/[A-Za-z]/) && part.match?(/\d/)
    end

    def host_of(address)
      URI(address.to_s).host&.downcase
    rescue URI::InvalidURIError
      nil
    end
  end
end
