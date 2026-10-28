module SiteVisitsHelper
  # The Site visits row on a project's builder view: the line under its name,
  # and the state beside its switch. overview: a Projects::GatherService.
  def site_visits_status(repo, overview)
    return free_project_status(overview) if overview.free_project

    case overview.site_state
    when :no_website then [ "Counted on the project's website, once it has one.", "Off" ]
    when :off, :paused then [ "Not counted.", overview.site_state == :paused ? "Paused" : "Off" ]
    else [ site_visits_counting(repo, overview.last_site_visit), repo.picks?("visits") ? "Shown" : "Hidden" ]
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

  # While Free counts another project, this one is paused with its script
  # on, and off without it.
  def free_project_status(overview)
    line = "Free counts site visits for one project, #{overview.free_project.name}."
    return [ line, "Off" ] unless overview.site_state == :paused

    [ "#{line} Visits here are not counted, and the totals so far stay.", "Paused" ]
  end

  # The latest visit says the script works without opening the setup.
  def site_visits_counting(repo, last_visit)
    line = repo.site_first_visit_at ? "Counted by Openstage's script on #{repo.site_host}." : "Openstage's script on #{repo.site_host}, waiting for its first visit."
    line += " Last visit #{time_ago_in_words(last_visit)} ago." if repo.site_first_visit_at && last_visit
    repo.user.pro? ? line : "#{line} Free counts site visits for one project, and this is it."
  end
end
