require "resolv"

module SiteVisits
  # One page view sent by Openstage's script, as much of it as the day's
  # counts keep (SiteVisitCount): its page's path, and for a visitor's first
  # view of the day the site they came from, the ref tag they followed and
  # their country. Never a query string, a whole referrer, a machine's own
  # name, or a part of a path that looks like an email address, an id, a
  # secret, an IP address or a place's coordinates.
  class PageView
    MAX_PATH = 200
    MAX_TAG = 64
    # A host as it names a site, at most as long as DNS allows: dotted, and
    # its last label a name, so never an IP address or a lone machine name.
    HOST = /\A[a-z0-9_-]+(\.[a-z0-9_-]+)*\.[a-z][a-z0-9-]*\z/
    MAX_HOST = 253
    # A machine on a home or office network, whose name can be its owner's
    # (pedros-macbook-pro.local).
    LOCAL = /\.(local|lan|internal|localhost|home\.arpa)\z/
    # Anywhere in a part of a path: an email address (an "@" with something
    # before it, so a handle such as @pedro stays), a UUID, ten digits or
    # more in a row, as a phone number has, an IPv4 address, or a latitude
    # and longitude. An IPv6 address is a whole part (Resolv::IPv6::Regex).
    PERSONAL = /.(@|%40)|\h{8}-\h{4}-\h{4}-\h{4}-\h{12}|\d{10,}|(?<![\d.])\d{1,3}(\.\d{1,3}){3}(?![\d.])|-?\d{1,3}\.\d{3,},-?\d{1,3}\.\d{3,}/i
    # 16 letters and digits or more in a row: a digest, an id or a token
    # once it mixes letters and digits.
    RUN = /[A-Za-z\d]{16,}/
    # Inside a word, a digit next to a letter or an upper-case letter right
    # after a lower-case one: a slug turns a few times (v2, GitHub, B2B), a
    # random token many times.
    TURN = /\d(?=[A-Za-z])|[A-Za-z](?=\d)|[a-z](?=[A-Z])/
    # A ref tag that also holds these is someone's, not a campaign's: an "@"
    # anywhere, a hex digest or id, or a JSON web token. A campaign's name
    # with a year or a number in it (summer2026) stays.
    SECRET_TAG = /@|(?<!\h)(\h{24}|\h{32}|\h{40}|\h{64})(?!\h)|\AeyJ[\w-]+\.[\w-]+\.[\w-]*\z/

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
    # with no site's name to give.
    def source
      return if @referrer.nil?
      return SiteVisitCount::DIRECT if @referrer.blank?

      host = host_of(@referrer)&.delete_prefix("www.")
      host if host&.match?(HOST) && !host.match?(LOCAL) && host.length <= MAX_HOST && !on_site?(@referrer)
    end

    # The page's ref or utm_source tag, the first given, in letters, digits,
    # ".", "-" and "_" alone. A tag with an email address, an id or a
    # secret in it (PERSONAL, SECRET_TAG) is dropped, not cleaned, so the
    # next one counts instead.
    def ref_tag
      params = URI.decode_www_form(URI(@url).query.to_s)
      tags = %w[ref utm_source].flat_map { |key| params.filter_map { |name, value| value if name == key } }.map { |tag| tag.scrub("") }
      tags.reject { |tag| tag.match?(PERSONAL) || tag.match?(SECRET_TAG) }.map { |tag| tag.downcase.gsub(/[^a-z0-9._-]/, "").first(MAX_TAG) }.find(&:present?)
    end

    # Two letters; Cloudflare's XX (unknown) and T1 (Tor) name no country.
    def country
      code = @country.to_s.strip.upcase
      code if code.match?(/\A[A-Z]{2}\z/) && code != "XX"
    end

    private

    # PERSONAL, a RUN mixing letters and digits, or a token that "-" or "_"
    # cut into short runs, as nanoid and Devise make them: 16 characters or
    # more mixing upper case, lower case and digits that TURN four times or
    # more. A slug in title case or with a product's name stays.
    def personal?(part)
      return true if part.match?(PERSONAL) || part.match?(Resolv::IPv6::Regex) || part.scan(RUN).any? { |run| run.match?(/[A-Za-z]/) && run.match?(/\d/) }

      part.length >= 16 && part.match?(/[A-Z]/) && part.match?(/[a-z]/) && part.match?(/\d/) && part.scan(TURN).size >= 4
    end

    # A forged mailto: or ldap: address fails as a component, not as a URI.
    def host_of(address)
      URI(address.to_s).host&.downcase
    rescue URI::Error
      nil
    end
  end
end
