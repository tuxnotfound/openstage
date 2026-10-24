module Analytics
  # The first day any of the pages picked had something to count: a visit, a
  # follower or a click, in the builder's zone; nil before anything happened.
  # The analytics chart starts there when it falls inside the window.
  class FindStartService < ApplicationService
    # pages: page keys, CountService::PAGE or repos' full names.
    attr_accessor :user, :pages
    attr_reader :first_day

    validates :user, presence: true

    private

    def execute
      firsts = [ *visits, *follows, *clicks ].compact
      @first_day = firsts.min&.in_time_zone(user.zone)&.to_date
    end

    def own?
      Array(pages).include?(CountService::PAGE)
    end

    def repos
      Array(pages) - [ CountService::PAGE ]
    end

    def visits
      [ (user.profile_views.minimum(:viewed_at) if own?),
        (user.project_views.where(repo_name: repos).minimum(:viewed_at) if repos.any?) ]
    end

    def follows
      confirmed = user.subscriptions.confirmed
      [ (confirmed.whole_page.minimum(:confirmed_at) if own?),
        (confirmed.projects.joins(:github_repo).where(github_repos: { full_name: repos }).minimum(:confirmed_at) if repos.any?) ]
    end

    # An entry's link counts for its project, or for the builder's page with none.
    def clicks
      on_entries = user.entry_clicks.joins(:entry).where(entries: { repo_name: own? ? [ nil, *repos ] : repos })
      [ on_entries.minimum(:clicked_at), (user.project_clicks.where(repo_name: repos).minimum(:clicked_at) if repos.any?) ]
    end
  end
end
