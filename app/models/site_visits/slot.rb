module SiteVisits
  # The one project whose site visits a builder's Free plan counts: the one
  # set up first (GithubRepo#site_set_up_at), its script on or off. It is
  # theirs for life, and only deleting it frees it. Pro counts every project
  # with its script on. When Pro ends nothing runs: the slot counts on, and
  # every other project with its script on pauses, its script still on its
  # site, nothing it sends kept, its totals kept. Read once, on the first
  # question that needs it, so a list of a builder's projects asks the
  # database once.
  class Slot
    def initialize(user)
      @user = user
    end

    # The project that holds it, nil before any is set up.
    def repo
      return @repo if defined?(@repo)

      @repo = @user.github_repos.site_set_up_first.first
    end

    # Whether visits to a project's website count now.
    def counts?(project)
      project.site_source == "script" && (@user.pro? || holds?(project))
    end

    # Where a project's site visits stand: :off without the script,
    # :counting, or :paused while Free counts another project.
    def state(project)
      if project.site_source.nil? then :off
      elsif counts?(project) then :counting
      else :paused
      end
    end

    # The project Free counts instead of this one, nil when this one can
    # count: always on Pro, and on Free while it holds the slot or none is
    # taken. Setting a project up is refused while there is one.
    def instead_of(project)
      repo unless @user.pro? || repo.nil? || holds?(project)
    end

    # The websites whose visits count now.
    def counting_hosts
      @user.github_repos.site_script_on.select { |project| counts?(project) }.filter_map(&:site_host)
    end

    private

    def holds?(project)
      repo&.id == project.id
    end
  end
end
