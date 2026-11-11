# A list of projects without its script (profiles/page/_more_projects), on
# the stage or the dashboard (manage): links and a search form that open the
# page again on another view of the list (Progress::Listing), keeping the
# page's own params. On the dashboard, whose entries read q already, the
# list's params carry a prefix.
module ProjectListHelper
  def project_list_path(user, listing, manage: false)
    params = { **project_list_kept(manage), **listing.to_params(prefix: project_list_prefix(manage)), anchor: ProjectsTableSerializer::MORE_ANCHOR }
    manage ? dashboard_path(**params) : profile_path(user.username, **params)
  end

  # What the search form sends beside the name: the page's params, and the
  # list's order and filter, from its first page.
  def project_list_hidden(listing, manage: false)
    project_list_kept(manage).merge(listing.with(query: "", page: 1).to_params(prefix: project_list_prefix(manage)))
  end

  def project_list_prefix(manage)
    manage ? Progress::Listing::DASHBOARD : ""
  end

  def project_list_kept(manage)
    request.query_parameters.except(*Progress::Listing.names(project_list_prefix(manage))).symbolize_keys
  end
end
