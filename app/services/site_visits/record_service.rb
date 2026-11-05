module SiteVisits
  # One page view on a project's website, sent by Openstage's script
  # (public/v.js), added to the day's totals in the builder's zone, and to
  # its counts by page, source, ref tag and country (SiteVisitCount). It
  # counts only from the project's own website, from a person rather than a
  # bot, for a project whose visits count (GithubRepo#counts_site_visits?),
  # and up to DAILY_LIMIT views per visitor and day. A visitor is their IP,
  # or their IPv6 network, hashed with a key that changes every day, deleted
  # within three days.
  class RecordService < ApplicationService
    # Past this, one visitor's page views on a site that day are dropped.
    DAILY_LIMIT = 200

    # token: the script's data-project; url: the page viewed; origin: the
    # request's Origin header, when the browser sent one; referrer: the
    # page's referrer, which the script sends with a page load's first view
    # only; country: the CF-IPCountry header.
    attr_accessor :token, :url, :origin, :ip, :user_agent, :referrer, :country
    attr_reader :counted

    validates :token, :url, :ip, presence: true
    validate :from_a_person, :for_a_counting_project, :from_its_website

    private

    def execute
      day = Time.current.in_time_zone(repo.user.zone).to_date
      transaction do
        hits, loads = record_visitor(day)
        @counted = hits <= DAILY_LIMIT
        add_to_day(day, hits: hits, first_load: !referrer.nil? && loads == 1) if counted
      end
      mark_first_visit if counted
    end

    def from_a_person
      errors.add(:user_agent, "is a bot's") if BotDetector.bot?(user_agent)
    end

    def for_a_counting_project
      errors.add(:token, "names no project that counts visits") unless repo&.counts_site_visits?
    end

    # The Origin header too, when there is one: the page's URL is the
    # script's word, the header the browser's.
    def from_its_website
      return unless repo

      on_site = view.on_site?(url) && (origin.blank? || view.on_site?(origin))
      errors.add(:url, "is not on the project's website") unless on_site
    end

    def repo
      return @repo if defined?(@repo)

      @repo = GithubRepo.joins(:user).merge(User.active).includes(:user).find_by(site_token: token.to_s) if token.present?
    end

    def view
      @view ||= PageView.new(url: url, referrer: referrer, country: country, site_host: repo.site_host)
    end

    # Its page views today and, of them, its page loads (the views sent
    # with a referrer), this one included.
    def record_visitor(day)
      SiteVisitor.upsert({ github_repo_id: repo.id, day: day, visitor_hash: visitor_hash(day), hits: 1, loads: referrer.nil? ? 0 : 1 },
                         unique_by: %i[github_repo_id day visitor_hash], returning: %i[hits loads],
                         on_duplicate: Arel.sql("hits = site_visitors.hits + 1, loads = site_visitors.loads + EXCLUDED.loads"))
                 .first.values_at("hits", "loads")
    end

    # The day's totals, then its counts by page, source, ref tag and country.
    def add_to_day(day, hits:, first_load:)
      first = hits == 1
      SiteVisitDay.upsert({ github_repo_id: repo.id, day: day, visits: 1, visitors: first ? 1 : 0 },
                          unique_by: %i[github_repo_id day],
                          on_duplicate: Arel.sql("visits = site_visit_days.visits + 1, visitors = site_visit_days.visitors + EXCLUDED.visitors, " \
                                                 "updated_at = EXCLUDED.updated_at"))
      SiteVisitCount.add(repo.id, day, view.counts(first: first, first_load: first_load))
    end

    # What the setup step shows once the script works.
    def mark_first_visit
      return if repo.site_first_visit_at

      GithubRepo.where(id: repo.id, site_first_visit_at: nil).update_all(site_first_visit_at: Time.current)
    end

    # The day's key comes from the app's secret, so a hash cannot be matched
    # with another day's, nor with the IP, without it.
    def visitor_hash(day)
      key = Rails.application.key_generator.generate_key("site-visitors/#{day.iso8601}", 32)
      OpenSSL::HMAC.hexdigest("SHA256", key, "#{repo.id}/#{network}")
    end

    # An IPv4 address as it is; an IPv6 address by its /64, the network a
    # home or an office gets, where one machine can take a new address at
    # will. Native, so an IPv4 address written as IPv6 (::ffff:a.b.c.d)
    # stays itself rather than masking to "::". A value that is not an
    # address is hashed as it came.
    def network
      address = IPAddr.new(ip).native
      address.ipv6? ? address.mask(64).to_s : address.to_s
    rescue IPAddr::InvalidAddressError
      ip
    end
  end
end
