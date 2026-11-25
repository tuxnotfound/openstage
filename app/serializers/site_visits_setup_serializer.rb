# The page Set up site visits (SiteVisits::Setup), as its script draws it
# (SiteSetupIsland): the projects to pick from, the one picked with its
# website, the line to paste and where it leads, where it stands
# (SiteVisitsStatusSerializer), and what a refused Continue said. project
# and status are nil for a builder with no project yet, who is asked to
# connect GitHub, as an empty chart asks (ChartFilterHelper#chart_step).
class SiteVisitsSetupSerializer < ApplicationSerializer
  include Rails.application.routes.url_helpers
  include SiteVisitsHelper

  # base_url: the app's, for the line (site_script_tag); website: what the
  # builder typed, on a refused Continue; refusal: why it was refused.
  def initialize(setup, base_url:, website: nil, refusal: nil)
    @setup = setup
    @base_url = base_url
    @website = website
    @refusal = refusal
  end

  def attributes
    repo = @setup.repo
    { projects: @setup.projects.map { |each| { id: each.id, label: label_of(each) } }, free: !@setup.user.pro?, refusal: @refusal.presence,
      project: (project_of(repo) if repo), status: (SiteVisitsStatusSerializer.new(@setup).as_json if repo),
      paths: { setup: site_visits_setup_path, pricing: pricing_path, privacy: privacy_path(anchor: "builders-sites"), connect: new_github_installation_path } }
  end

  private

  # A repo under another owner says whose, as Settings does.
  def label_of(repo)
    repo.owner_login.casecmp?(@setup.user.github_username.to_s) ? repo.name : repo.full_name
  end

  def project_of(repo)
    { id: repo.id, name: repo.name, host: repo.site_host, website: @website || repo.website.to_s, visit: repo.outbound_url("visit"),
      line: (site_script_tag(repo, base_url: @base_url) if repo.site_token), note: (site_script_note(repo.site_host) if repo.site_host),
      page: project_page_path(@setup.user.username, repo.name), dashboard: dashboard_path(project: repo.id),
      numbers: project_numbers_path(repo), status_path: api_site_visits_path(repo.id) }
  end
end
