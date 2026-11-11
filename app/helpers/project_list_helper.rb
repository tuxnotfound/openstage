# The stage's list of projects without its script (profiles/page/_more_projects):
# links and a search form that open the stage again on another view of the
# list (Progress::Listing), keeping the chart's own params.
module ProjectListHelper
  LIST_PARAMS = %w[sort q live page].freeze

  def project_list_path(user, listing)
    profile_path(user.username, **project_list_kept, **listing.to_params, anchor: ProjectsTableSerializer::MORE_ANCHOR)
  end

  # What the search form sends beside the name: the chart's params, and the
  # list's order and filter, from its first page.
  def project_list_hidden(listing)
    project_list_kept.merge(listing.with(query: "", page: 1).to_params)
  end

  def project_list_kept
    request.query_parameters.except(*LIST_PARAMS).symbolize_keys
  end
end
