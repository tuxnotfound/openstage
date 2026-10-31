require "resolv"

module SiteVisits
  # One page view sent by Openstage's script, as much of it as the day's
  # counts keep (SiteVisitCount): its page's path; for a visitor's first
  # view of the day their country; and for their first page load of the day
  # the site they came from and the ref tag they followed. Never a query
  # string, a whole referrer, a machine's own name, or a part of a path that
  # looks like an email address, a phone or card number, an id, a secret, an
  # IP address or a place's coordinates.
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
    # more in a row, an IPv4 address, or a latitude and longitude. An IPv6
    # address is a whole part (Resolv::IPv6::Regex).
    PERSONAL = /.(@|%40)|\h{8}-\h{4}-\h{4}-\h{4}-\h{12}|\d{10,}|(?<![\d.])\d{1,3}(\.\d{1,3}){3}(?![\d.])|-?\d{1,3}\.\d{3,},-?\d{1,3}\.\d{3,}/i
    # Digits split by dashes, dots, spaces or brackets, as phone, card and
    # bank account numbers are written (415-555-1234, +44 20 7946 0958,
    # 4111 1111 1111 1111); one with a DATE in it is a dated slug's
    # (release-1.4.2-2026-10-30).
    NUMBER = /(?<![\w.])\+?\(?\d(?:[-. ()]{0,2}\d)+(?!\w)/
    DATE = /\d{4}[-.]\d\d[-.]\d\d/
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
    # Cloudflare's codes that name no country: XX (unknown) and T1 (Tor).
    NO_COUNTRY = %w[XX T1].freeze

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

    # Whether a referrer's host names a site, so a panel may show it:
    # Openstage's own pages keep their referrers' hosts as they came.
    def self.site?(host)
      name = host.to_s.downcase.delete_prefix("www.")
      name.match?(HOST) && !name.match?(LOCAL) && name.length <= MAX_HOST
    end

    # Whether an address is on the project's website: www. and the bare
    # domain are one site.
    def on_site?(address)
      host = host_of(address)
      host.present? && @site_host.present? && host.delete_prefix("www.") == @site_host.delete_prefix("www.")
    end

    # What it adds to the day's counts, by kind: its page always; on its
    # visitor's first view of the day (first) their country; on their first
    # page load of the day (first_load), the first view the script sent with
    # a referrer, their source and ref tag. An app that changes its page as
    # it loads sends two views at once, and either can reach Openstage first.
    def counts(first:, first_load:)
      counts = { "page" => page }
      counts["country"] = country if first
      counts.merge!("source" => source, "ref" => ref_tag) if first_load
      counts.compact
    end

    # The path alone, its trailing slash dropped, a part that looks personal
    # or secret as "*", judged as its visitor reads it (decoded) and kept as
    # it came.
    def page
      path = URI(@url).path.split("/").map { |part| personal?(decoded(part)) ? "*" : part }.join("/")
      path.presence&.first(MAX_PATH) || "/"
    end

    # The referrer's host, www. dropped; DIRECT for an empty referrer; nil
    # without a referrer, for one on the project's own website, or for one
    # with no site's name to give.
    def source
      return if @referrer.nil?
      return SiteVisitCount::DIRECT if @referrer.blank?

      host = host_of(@referrer)&.delete_prefix("www.")
      host if self.class.site?(host) && !on_site?(@referrer)
    end

    # The page's ref or utm_source tag, the first given, in letters, digits,
    # ".", "-" and "_" alone. A tag with an email address, a phone number,
    # an id or a secret in it (PERSONAL, NUMBER, SECRET_TAG) is dropped, not
    # cleaned, so the next one counts instead.
    def ref_tag
      params = URI.decode_www_form(URI(@url).query.to_s)
      tags = %w[ref utm_source].flat_map { |key| params.filter_map { |name, value| value if name == key } }.map { |tag| tag.scrub("") }
      tags.reject { |tag| tag.match?(PERSONAL) || number?(tag) || tag.match?(SECRET_TAG) }.map { |tag| tag.downcase.gsub(/[^a-z0-9._-]/, "").first(MAX_TAG) }.find(&:present?)
    end

    # Two letters, none of NO_COUNTRY.
    def country
      code = @country.to_s.strip.upcase
      code if code.match?(/\A[A-Z]{2}\z/) && NO_COUNTRY.exclude?(code)
    end

    private

    # The browser sends "é" as "%C3%A9" and a space as "%20", whose hex
    # would read as letters and digits. URI has checked every escape; bytes
    # that are not UTF-8 (%FF) are dropped, as the patterns cannot read them.
    def decoded(part)
      URI.decode_uri_component(part).scrub("")
    end

    # PERSONAL, an IPv6 address, a phone, card or bank account number, or a
    # token.
    def personal?(part)
      part.match?(PERSONAL) || part.match?(Resolv::IPv6::Regex) || number?(part) || token?(part)
    end

    # A NUMBER of 10 to 19 digits, as many as a phone, card or bank account
    # number has, and no DATE.
    def number?(text)
      text.scan(NUMBER).any? { |run| run.count("0-9").between?(10, 19) && !run.match?(DATE) }
    end

    # A RUN mixing letters and digits, or a token that "-" or "_" cut into
    # short runs, as nanoid and Devise make them: 16 characters or more
    # mixing upper case, lower case and digits that TURN four times or more.
    # A slug in title case or with a product's name stays.
    def token?(part)
      return true if part.scan(RUN).any? { |run| run.match?(/[A-Za-z]/) && run.match?(/\d/) }

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
