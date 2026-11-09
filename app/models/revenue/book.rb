module Revenue
  # What a builder's Stripe account holds for their projects, as the pages read
  # it: the last day read, the first day each project had revenue, and its days
  # in one currency (Levels). Only products counted for a project read here, and
  # nothing while Stripe refuses the key or reads keep failing, so no stale
  # figure stands as verified.
  class Book
    def initialize(user)
      @user = user
    end

    def account
      return @account if defined?(@account)

      @account = @user.revenue_accounts.find_by(provider: "stripe")
    end

    def live?
      account.present? && account.refused_at.nil? && !account.stale?
    end

    # The last day read; nil before the first read.
    def read_day
      account&.read_through
    end

    # { repo id => its first day with revenue }.
    def firsts
      @firsts ||= live? ? counted_days.group("revenue_products.github_repo_id").minimum(:day) : {}
    end

    # The projects with revenue.
    def repos
      @user.github_repos.where(id: firsts.keys).to_a
    end

    # { number's key => { repo's full name => its first day } }, of these
    # projects: MRR and paying customers begin together, at the first sale.
    def first_days(some = repos)
      days = some.filter_map { |repo| [ repo.full_name, firsts[repo.id] ] if firsts.key?(repo.id) }.to_h
      Progress::Numbers::REVENUE.index_with { days }
    end

    # Levels of these projects, from a day on; nil from for every day. With no
    # day since then, their revenue has ended: they stand at nothing, in the
    # currency it last was in.
    def levels(repos, from: nil)
      days = counted_days.where(revenue_products: { github_repo_id: repos.map(&:id) })
      rows = (from ? days.where(day: from..) : days).pluck("revenue_products.github_repo_id", :day, :currency, :mrr).map do |repo_id, day, currency, mrr|
        Levels::Row.new(repo_id: repo_id, day: day, currency: currency, mrr: mrr)
      end
      Levels.new(rows, customers: customers(repos, from), ended_in: (days.order(day: :desc).pick(:currency) if rows.empty?))
    end

    private

    # { repo id => { date => its paying customers } }: a customer counts once
    # for a project, however many of its products they pay for.
    def customers(repos, from)
      projects = account.revenue_products.where(github_repo_id: repos.map(&:id)).pluck(:id, :github_repo_id).to_h
      days = account.revenue_customer_days.where("product_ids && ARRAY[?]::bigint[]", projects.keys)
      (from ? days.where(day: from..) : days).pluck(:day, :product_ids, :customers).each_with_object({}) do |(day, product_ids, customers), counted|
        projects.values_at(*product_ids).compact.uniq.each do |repo_id|
          per_day = counted[repo_id] ||= Hash.new(0)
          per_day[day] += customers
        end
      end
    end

    def counted_days
      RevenueDay.joins(:revenue_product).where(revenue_products: { revenue_account_id: account.id }).where.not(revenue_products: { github_repo_id: nil })
    end
  end
end
