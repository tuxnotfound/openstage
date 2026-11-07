module Revenue
  # The one project whose MRR a builder's Free plan counts: the one first given
  # a product (GithubRepo#revenue_set_up_at), theirs for life, and only deleting
  # it frees it. On Free only its builder sees it; showing MRR to visitors is
  # Pro, for every project. Read once, on the first question that needs it.
  class Slot
    def initialize(user)
      @user = user
    end

    # The project that holds it, nil before any is set up.
    def repo
      return @repo if defined?(@repo)

      @repo = @user.github_repos.revenue_set_up_first.first
    end

    # The project Free counts instead of this one, nil when this one can
    # count: always on Pro, and on Free while it holds the slot or none is
    # taken. Giving it a product is refused while there is one.
    def instead_of(project)
      repo unless @user.pro? || repo.nil? || repo.id == project.id
    end
  end
end
