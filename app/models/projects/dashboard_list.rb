module Projects
  # The dashboard's list of a builder's projects, as its Projects tab shows
  # it: a row per repo with work on Openstage (GithubRepo.with_entries), each
  # with its rank on the stage, so its colour while it wears one (the pinned
  # ones, Progress::Projects), and whether the stage shows it. No number.
  # The stage's order, the hidden ones last. Up to MANY projects, every one
  # is listed. Past it the list opens on the pinned ones; All and Hidden are
  # the other views, PER_PAGE rows a page, and a search narrows the view it
  # is typed in, by name. row: a project the list opens on, in the view and
  # on the page that hold it.
  class DashboardList
    MANY = ProgressChart::Palette::SIZE
    PER_PAGE = Progress::ListService::PER_PAGE
    VIEWS = %w[pinned all hidden].freeze

    # pinned: it wears a colour on the stage, as the palette gives the
    # pinned ones (Projects::PinService).
    Row = Data.define(:repo, :rank) do
      def pinned?
        repo.included? && !rank.nil? && ProgressChart::Palette.colored?(rank)
      end
    end

    attr_reader :view, :query, :page

    def initialize(user, view: nil, query: nil, page: nil, row: nil)
      @user = user
      @query = query.to_s.strip.first(Progress::Listing::QUERY_LENGTH)
      @view = view.to_s.presence_in(VIEWS) || (many? ? "pinned" : "all")
      @page = [ page.to_i, 1 ].max
      land_on(row) if row.present?
    end

    def many?
      rows.size > MANY
    end

    def count(view = @view)
      in_view(view).size
    end

    # The rows the search keeps in the view, before paging.
    def found
      @found ||= in_view(@view).select { |row| @query.empty? || row.repo.name.downcase.include?(@query.downcase) }
    end

    def pages
      many? ? [ found.size.fdiv(PER_PAGE).ceil, 1 ].max : 1
    end

    def shown
      return found unless many?

      found.slice((current_page - 1) * PER_PAGE, PER_PAGE) || []
    end

    def current_page
      [ @page, pages ].min
    end

    # A project's row by its repo's full name, nil for none.
    def find(full_name)
      @by_name ||= rows.index_by { |row| row.repo.full_name }
      @by_name[full_name]
    end

    # A project's colour on the stage, nil without one.
    def color_class(repo)
      row = find(repo&.full_name)
      ProgressChart::Palette.project_class(row.rank) if row&.pinned?
    end

    # The stage's projects that wear a colour, by full name.
    def pinned_names
      rows.select(&:pinned?).map { |row| row.repo.full_name }
    end

    private

    def rows
      @rows ||= begin
        repos = @user.github_repos.with_entries.to_a
        ranks = Progress::Projects.new(@user.entries.counted_on_page, pinned: repos.select(&:pinned?).map(&:full_name)).all.to_h { [ _1.repo, _1.rank ] }
        stage, hidden = repos.partition(&:included?)
        ordered = stage.sort_by { |repo| [ ranks[repo.full_name] || Float::INFINITY, repo.name.downcase, repo.full_name ] } +
                  hidden.sort_by { |repo| [ repo.name.downcase, repo.full_name ] }
        ordered.map { |repo| Row.new(repo: repo, rank: (ranks[repo.full_name] if repo.included?)) }
      end
    end

    def in_view(view)
      case view
      when "pinned" then rows.select(&:pinned?)
      when "hidden" then rows.reject { |row| row.repo.included? }
      else rows
      end
    end

    def land_on(id)
      row = rows.find { |each| each.repo.id.to_s == id.to_s }
      return unless row && many?

      @query = ""
      @view = %w[pinned hidden all].find { |view| in_view(view).include?(row) }
      @page = (in_view(@view).index(row) / PER_PAGE) + 1
    end
  end
end
