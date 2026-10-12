# GitHub's REST API with a token that reads a builder's repos: their sign-in
# token, or an installation token for private repos picked in the App. Only
# needs Contents and Metadata read.
class GithubGateway < ApplicationGateway
  API_VERSION = "2022-11-28".freeze

  CommitFile = Data.define(:filename, :additions, :deletions)
  Release = Data.define(:id, :name, :tag_name, :html_url, :published_at, :author_login, :draft)

  # The files one commit changed, with lines added and removed in each. GitHub
  # lists at most 300 files per commit, which is plenty for a week card.
  def self.commit_files(full_name, sha, token:)
    body = get("/repos/#{repo_path(full_name)}/commits/#{ERB::Util.url_encode(sha)}", headers: auth(token))
    body[:files].to_a.map do |file|
      CommitFile.new(filename: file[:filename].to_s, additions: file[:additions].to_i, deletions: file[:deletions].to_i)
    end
  end

  # A repo's latest releases, newest first.
  def self.releases(full_name, token:, per_page: 30)
    get("/repos/#{repo_path(full_name)}/releases", query: { per_page: per_page }, headers: auth(token)).to_a.map do |release|
      Release.new(id: release[:id], name: release[:name], tag_name: release[:tag_name], html_url: release[:html_url],
                  published_at: release[:published_at], author_login: release.dig(:author, :login), draft: release[:draft])
    end
  end

  # "owner/repo" with each part escaped, never the slash between them.
  def self.repo_path(full_name)
    full_name.to_s.split("/", 2).map { |part| ERB::Util.url_encode(part) }.join("/")
  end

  def self.base_url
    "https://api.github.com"
  end

  def self.auth(token)
    { "Authorization" => "Bearer #{token}", "X-GitHub-Api-Version" => API_VERSION }
  end
  private_class_method :repo_path, :base_url, :auth
end
