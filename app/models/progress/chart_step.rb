module Progress
  # What a builder can do for a chart with nothing to draw: :repos, :hidden,
  # :site, :stripe, or nil with all of it done. repo: the project of a project's
  # page; nil for all of them. nothing_shown: none of its numbers show.
  # steps: the ones the page asks, in this order; an analytics tab asks only
  # those that fill its chart (Analytics::Tab#steps).
  class ChartStep
    STEPS = %i[repos hidden site stripe].freeze

    def initialize(user, repo: nil, nothing_shown: false, steps: STEPS)
      @user = user
      @repo = repo
      @nothing_shown = nothing_shown
      @steps = steps
    end

    def key
      STEPS.find { |step| @steps.include?(step) && due?(step) }
    end

    private

    def due?(step)
      case step
      when :repos then !repos.with_entries.exists?
      when :hidden then @nothing_shown && repos.any? { |repo| repo.hidden_numbers.any? }
      when :site then !repos.where.not(site_set_up_at: nil).exists?
      # Free's MRR never draws on a chart, so connecting would not fill this one.
      when :stripe then @user.pro? && @user.revenue_accounts.none?
      end
    end

    def repos
      @repo ? @user.github_repos.where(id: @repo.id) : @user.github_repos
    end
  end
end
