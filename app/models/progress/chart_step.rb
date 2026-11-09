module Progress
  # What a builder can do for a chart with nothing to draw: :repos, :hidden,
  # :site, :stripe, or nil with all of it done. repo: the project of a project's
  # page; nil for all of them. nothing_shown: none of its numbers show.
  class ChartStep
    def initialize(user, repo: nil, nothing_shown: false)
      @user = user
      @repo = repo
      @nothing_shown = nothing_shown
    end

    def key
      return :repos unless repos.with_entries.exists?
      return :hidden if @nothing_shown && repos.any? { |repo| repo.hidden_numbers.any? }
      return :site unless repos.where.not(site_set_up_at: nil).exists?

      # Free's MRR never draws on a chart, so connecting would not fill this one.
      :stripe if @user.pro? && @user.revenue_accounts.none?
    end

    private

    def repos
      @repo ? @user.github_repos.where(id: @repo.id) : @user.github_repos
    end
  end
end
