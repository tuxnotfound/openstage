module Analytics
  # The first day each page counted each number, ever, in the builder's zone:
  # each project's first public commit, first sale and first visit and visitor
  # to its website, and the first visitor, follower and click out on the
  # builder's own page (CountService::PAGE) and on each project's page. A chart
  # starts where the numbers it draws start, and a number compares with the
  # window before only once it counted before the window began. It reads
  # only the numbers wanted, as CountService does.
  class FindStartService < ApplicationService
    # numbers: the keys wanted, nil for every one; sites: the projects whose
    # site visits count, as GithubRepo ids, nil for every one.
    attr_accessor :user, :numbers, :sites
    # firsts: {number's key => {page => date}}.
    attr_reader :firsts

    validates :user, presence: true

    private

    def execute
      @firsts = { **on_github, **on_websites, **on_stripe, **on_openstage }
    end

    def wanted?(keys)
      numbers.nil? || numbers.intersect?(keys)
    end

    def on_github
      wanted?(%w[commits]) ? { "commits" => commits } : {}
    end

    def on_websites
      return {} unless wanted?(CountService::ON_WEBSITES)

      visits, visitors = site_visits
      { "visits" => visits, "site_visitors" => visitors }
    end

    def on_stripe
      wanted?(CountService::ON_STRIPE) ? Revenue::Book.new(user).first_days : {}
    end

    def on_openstage
      return {} unless wanted?(CountService::ON_OPENSTAGE)

      views = first_views
      { "visitors" => views, "views" => views, "follows" => follows, "clicks" => clicks }
    end

    def first_views
      earliest(user.page_days.group(:page).minimum(:day),
               days(earliest(own(split.raw(user.profile_views, :viewed_at).minimum(:viewed_at)),
                             split.raw(user.project_views, :viewed_at).group(:repo_name).minimum(:viewed_at))))
    end

    def split
      @split ||= Split.new(user)
    end

    # As the public page counts them: public, merges and dependency bumps left out.
    def commits
      days(user.entries.publicly_counted.without_tooling_noise.commits.where.not(repo_name: nil).group(:repo_name).minimum(:occurred_at))
    end

    # Counted on the builder's day already: the first day with a visit, and
    # the first with a visitor.
    def site_visits
      scope = sites ? user.site_visit_days.where(github_repo_id: sites) : user.site_visit_days
      firsts = scope.group("github_repos.full_name")
                   .pluck("github_repos.full_name", Arel.sql("MIN(site_visit_days.day)"), Arel.sql("MIN(site_visit_days.day) FILTER (WHERE site_visit_days.visitors > 0)"))
      [ firsts.to_h { |page, day, _| [ page, day ] }, firsts.filter_map { |page, _, day| [ page, day ] if day }.to_h ]
    end

    # Confirmed: for the builder's page, or for one project.
    def follows
      confirmed = user.subscriptions.confirmed
      days(earliest(own(confirmed.whole_page.minimum(:confirmed_at)),
                    confirmed.projects.joins(:github_repo).group("github_repos.full_name").minimum(:confirmed_at)))
    end

    # A project's Visit and View on GitHub buttons, and the links in the
    # builder's entries: an entry's for its project, or their page with none.
    def clicks
      on_entries = split.raw(user.entry_clicks.joins(:entry), :clicked_at).group("entries.repo_name").minimum(:clicked_at)
      earliest(page_keys(user.entry_click_days.joins(:entry).group("entries.repo_name").minimum(:day)),
               user.page_counts.buttons.group(:page).minimum(:day),
               days(earliest(page_keys(on_entries), split.raw(user.project_clicks, :clicked_at).group(:repo_name).minimum(:clicked_at))))
    end

    def page_keys(by_repo)
      by_repo.transform_keys { |repo| repo || CountService::PAGE }
    end

    def own(time)
      time ? { CountService::PAGE => time } : {}
    end

    # {page => time} from several, the earliest for each page.
    def earliest(*parts)
      parts.reduce({}) { |all, part| all.merge(part) { |_, one, other| [ one, other ].min } }
    end

    def days(times)
      times.transform_values { |time| time.in_time_zone(user.zone).to_date }
    end
  end
end
