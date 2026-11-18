module Analytics
  # The rows of an analytics tab (Tab), as Progress::Rows: the builder's
  # stage first on the tabs that list it, then each project in the public
  # page's order and colours. A row counts the tab's numbers it has counted
  # on any day, and shows every one: the page is its builder's alone, and a
  # project's switches only say what visitors see. A tab that lists only
  # the projects counting one of its numbers leaves the others out; one that
  # lists every project keeps them idle, with no box, never in view. The
  # pages asked for stay in view as far as they have a box
  # (Progress::Filter.in_view), and the projects past the palette while all
  # of them are, so their numbers stay in the totals.
  class PageRows
    STAGE = "Your stage".freeze

    # counts: a Progress::Counts of the tab's numbers; pages: the keys asked
    # for, none for all of them; slot: the builder's SiteVisits::Slot.
    def initialize(user:, tab:, counts:, pages:, slot:)
      @user = user
      @tab = tab
      @counts = counts
      @pages = pages
      @slot = slot
    end

    def all
      rows = listed.map { |key, name, rank| row(key, name, rank) }
      rows = rows.reject(&:idle) unless @tab.every_project?
      in_view = Progress::Filter.in_view(@pages, rows.select(&:boxed?).map(&:key))
      rows.map { |row| row.with(on: !row.idle && (in_view.empty? || in_view.include?(row.key))) }
    end

    private

    # [key, name, rank] of each page.
    def listed
      stage = @tab.stage?(@user) ? [ [ CountService::PAGE, STAGE, nil ] ] : []
      stage + projects.map { |project| [ project.repo, project.name, project.rank ] }
    end

    def projects
      @projects ||= Progress::Projects.new(@user.entries.publicly_counted.without_tooling_noise, pinned: @user.github_repos.pinned_names).all
    end

    def row(key, name, rank)
      repo = synced[key]
      counted = @tab.numbers_for(@user).select { |number| @counts.first_day(number, [ key ]) }
      Progress::Row.new(key: key, name: name, rank: rank, color_class: ProgressChart::Palette.project_class(rank), repo: repo, on: false,
                        counted: counted, shown: counted, site: (@slot.state(repo) if repo), idle: counted.empty?)
    end

    def synced
      @synced ||= @user.github_repos.by_full_name(projects.map(&:repo))
    end
  end
end
