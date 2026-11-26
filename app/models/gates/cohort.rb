module Gates
  # The builders who signed up in a window, as the gates read them (the
  # control tower's PLAN.md, section 5): who was retained in their second
  # week, days 7 to 13 after signup, by any clause of the 2026-10-17 rule
  # (seen signed in, their stage or a project page seen twice by others, a
  # badge or an embed shown once); whose project page was reached from GitHub
  # or from a site of their own; and who set a number up. For /admin, which
  # counted the first clause alone.
  class Cohort
    SECOND_WEEK = "%<at>s >= DATE(users.created_at) + 7 AND %<at>s < DATE(users.created_at) + 14".freeze
    SEEN_BY_OTHERS = 2
    GITHUB = /(\A|\.)github\.com\z/

    # week: :ahead before day 7, :open on days 7 to 13, :closed after. views
    # and impressions are the second week's; outside, sites and counting are
    # since signup.
    Row = Data.define(:user, :week, :came_back, :views, :impressions, :outside, :sites, :counting, :stripe) do
      def first_day = user.created_at.utc.to_date + 7
      def last_day = first_day + 6
      def seen? = views >= SEEN_BY_OTHERS
      def shown? = impressions.positive?
      def retained? = came_back || seen? || shown?
    end

    # users: the builders to read, a relation.
    def initialize(users, today: Date.current)
      @users = users
      @today = today
    end

    # Each builder, the earliest signup first.
    def rows
      @rows ||= @users.order(:created_at, :id).map { |user| row_of(user) }
    end

    # Those whose second week has begun: a week still ahead retains no one.
    def old_enough
      rows.reject { |row| row.week == :ahead }
    end

    private

    def row_of(user)
      Row.new(user: user, week: week_of(user), came_back: came_back.include?(user.id), views: views.fetch(user.id, 0),
              impressions: impressions.fetch(user.id, 0), outside: outside.fetch(user.id, 0),
              sites: sites.fetch(user.id, 0), counting: counting.fetch(user.id, 0), stripe: stripe.include?(user.id))
    end

    def week_of(user)
      first = user.created_at.utc.to_date + 7
      return :ahead if @today < first

      @today > first + 6 ? :closed : :open
    end

    def came_back
      @came_back ||= Event.second_week_user_ids(@users).to_set
    end

    # Never the builder's own view nor a bot's: neither is recorded.
    def views
      @views ||= in_second_week(ProfileView).merge(in_second_week(ProjectView)) { |_id, stage, projects| stage + projects }
    end

    def impressions
      @impressions ||= in_second_week(BadgeImpression)
    end

    def in_second_week(records)
      at = "#{records.table_name}.viewed_at"
      records.joins(:user).merge(@users).where(format(SECOND_WEEK, at: at)).group(:user_id).count
    end

    # Views of a project's page that came from GitHub or from a site of the
    # builder's own, by the host each view keeps.
    def outside
      @outside ||= referrers.each_with_object(Hash.new(0)) do |((id, referrer), count), sums|
        host = host_of(referrer)
        sums[id] += count if host.present? && (host.match?(GITHUB) || own_hosts[id].include?(host))
      end
    end

    # A builder's own sites: each project's website, and the one on their stage.
    def own_hosts
      @own_hosts ||= begin
        hosts = Hash.new { |all, id| all[id] = Set.new }
        repos.each { |repo| hosts[repo.user_id] << repo.site_host if repo.site_host }
        @users.where.not(website_url: [ nil, "" ]).pluck(:id, :website_url).each { |id, url| hosts[id] << host_of(url) }
        hosts
      end
    end

    def referrers
      ProjectView.where(user_id: @users.select(:id)).where.not(referrer: [ nil, "" ]).group(:user_id, :referrer).count
    end

    # Views kept before the host alone was stored hold the whole address.
    def host_of(referrer)
      (referrer.include?("://") ? URI(referrer).host : referrer).to_s.downcase
    rescue URI::InvalidURIError
      ""
    end

    def sites
      @sites ||= repos.select(&:site_set_up_at).group_by(&:user_id).transform_values(&:size)
    end

    def counting
      @counting ||= repos.select(&:site_first_visit_at).group_by(&:user_id).transform_values(&:size)
    end

    def repos
      @repos ||= GithubRepo.where(user_id: @users.select(:id))
                           .select(:id, :user_id, :full_name, :private_repo, :website_edit, :homepage, :site_set_up_at, :site_first_visit_at).to_a
    end

    def stripe
      @stripe ||= RevenueAccount.where(user_id: @users.select(:id), refused_at: nil).pluck(:user_id).to_set
    end
  end
end
