module SiteVisits
  # One page view on a project's website, sent by Openstage's script
  # (public/v.js), added to the day's totals in the builder's zone. It counts
  # only from the project's own website, from a person rather than a bot, for a
  # project whose visits count (GithubRepo#counts_site_visits?), and up to
  # DAILY_LIMIT views per visitor and day. A visitor is their IP hashed with a
  # key that changes every day, kept until the day is over.
  class RecordService < ApplicationService
    # Past this, one address's page views on a site that day are dropped.
    DAILY_LIMIT = 200

    # token: the script's data-project; url: the page viewed; origin: the
    # request's Origin header, when the browser sent one.
    attr_accessor :token, :url, :origin, :ip, :user_agent
    attr_reader :counted

    validates :token, :url, :ip, presence: true
    validate :from_a_person, :for_a_counting_project, :from_its_website

    private

    def execute
      day = Time.current.in_time_zone(repo.user.zone).to_date
      transaction do
        hits = record_visitor(day)
        @counted = hits <= DAILY_LIMIT
        add_to_day(day, first: hits == 1) if counted
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

      host = repo.site_host
      on_site = same_site?(host_of(url), host) && (origin.blank? || same_site?(host_of(origin), host))
      errors.add(:url, "is not on the project's website") unless on_site
    end

    def repo
      return @repo if defined?(@repo)

      @repo = GithubRepo.joins(:user).merge(User.active).includes(:user).find_by(site_token: token.to_s) if token.present?
    end

    # Its page views today, this one included.
    def record_visitor(day)
      SiteVisitor.upsert({ github_repo_id: repo.id, day: day, visitor_hash: visitor_hash(day), hits: 1 },
                         unique_by: %i[github_repo_id day visitor_hash], returning: :hits,
                         on_duplicate: Arel.sql("hits = site_visitors.hits + 1")).first.fetch("hits")
    end

    def add_to_day(day, first:)
      SiteVisitDay.upsert({ github_repo_id: repo.id, day: day, visits: 1, visitors: first ? 1 : 0 },
                          unique_by: %i[github_repo_id day],
                          on_duplicate: Arel.sql("visits = site_visit_days.visits + 1, visitors = site_visit_days.visitors + EXCLUDED.visitors, " \
                                                 "updated_at = EXCLUDED.updated_at"))
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
      OpenSSL::HMAC.hexdigest("SHA256", key, "#{repo.id}/#{ip}")
    end

    # www. and the bare domain are one site.
    def same_site?(one, other)
      one.present? && other.present? && one.delete_prefix("www.") == other.delete_prefix("www.")
    end

    def host_of(address)
      URI(address.to_s).host&.downcase
    rescue URI::InvalidURIError
      nil
    end
  end
end
