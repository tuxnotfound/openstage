module SiteVisitsHelper
  # The numbers a page's chart can draw, as its toggles name them.
  CHART_NUMBERS = { "commits" => "Commits", "visits" => "Site visits" }.freeze

  # The numbers on: both with site visits to draw, unless ?show= names one.
  def chart_numbers(site_view, show)
    return [ "commits" ] unless site_view

    CHART_NUMBERS.key?(show) ? [ show ] : CHART_NUMBERS.keys
  end

  # The chart for the numbers on: commits alone, visits alone, or both.
  def numbers_chart(section, site_view, numbers)
    return ProgressChart::Trend.new(section) if numbers == [ "commits" ]

    numbers == [ "visits" ] ? site_view.visits_chart : site_view.compare_chart
  end

  # A toggle's link: the number switched, the last one on staying on.
  def chart_numbers_show(numbers, number)
    on = numbers.include?(number) ? numbers - [ number ] : numbers + [ number ]
    on = numbers if on.empty?
    on.size == CHART_NUMBERS.size ? nil : on.first
  end

  # The Site visits row on a project's builder view: the line under its name,
  # and the state beside its switch. overview: a Projects::GatherService.
  def site_visits_status(repo, overview)
    case overview.site_state
    when :no_website then [ "Counted on the project's website, once it has one.", "Off" ]
    when :off then [ overview.free_site ? "Free counts one site, and #{site_name(overview.free_site)} counts now." : "Not counted.", "Off" ]
    when :paused then [ "Paused: Free counts one site, and #{site_name(overview.free_site)} counts now.", "Paused" ]
    else [ site_visits_counting(repo, overview.last_site_visit), repo.shows?("visits") ? "Shown" : "Hidden" ]
    end
  end

  # The line a builder pastes into their site's pages.
  def site_script_tag(repo)
    %(<script defer src="#{request.base_url}/v.js" data-project="#{repo.site_token}"></script>)
  end

  # "today at 14:02", or "Oct 24", in the builder's zone.
  def site_first_visit(repo)
    zone = repo.user.zone
    at = repo.site_first_visit_at.in_time_zone(zone)
    at.to_date == Time.current.in_time_zone(zone).to_date ? "today at #{at.strftime('%H:%M')}" : at.strftime("%b %-d")
  end

  private

  # The latest visit says the script works without opening the setup.
  def site_visits_counting(repo, last_visit)
    line = repo.site_first_visit_at ? "Counted by Openstage's script on #{repo.site_host}." : "Openstage's script on #{repo.site_host}, waiting for its first visit."
    line += " Last visit #{time_ago_in_words(last_visit)} ago." if repo.site_first_visit_at && last_visit
    repo.user.pro? ? line : "#{line} Free counts one site, and this is it."
  end

  def site_name(repo)
    repo.site_host || repo.name
  end
end
