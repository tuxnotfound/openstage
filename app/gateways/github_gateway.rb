# GitHub's REST API with a token that reads a builder's repos: their sign-in
# token, or an installation token for private repos picked in the App. Commits
# and releases need Contents and Metadata read; pull requests and deployments
# each need their own read permission, and GitHub answers 403 without it.
class GithubGateway < ApplicationGateway
  API_VERSION = "2022-11-28".freeze

  CommitFile = Data.define(:filename, :additions, :deletions)
  Release = Data.define(:id, :name, :tag_name, :html_url, :published_at, :author_login, :draft)
  PullRequest = Data.define(:id, :number, :title, :merged_at, :author_login)
  Deployment = Data.define(:id, :environment, :created_at)

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

  # A repo's merged pull requests among the 50 closed ones updated last. GitHub
  # cannot filter on merged, so closed ones without a merge are dropped here.
  def self.merged_pulls(full_name, token:)
    query = { state: "closed", sort: "updated", direction: "desc", per_page: 50 }
    pulls = get("/repos/#{repo_path(full_name)}/pulls", query: query, headers: auth(token)).to_a
    pulls.select { |pull| pull[:merged_at].present? }.map do |pull|
      PullRequest.new(id: pull[:id], number: pull[:number], title: pull[:title], merged_at: pull[:merged_at],
                      author_login: pull.dig(:user, :login))
    end
  end

  # A repo's latest deployments, newest first.
  def self.deployments(full_name, token:)
    get("/repos/#{repo_path(full_name)}/deployments", query: { per_page: 50 }, headers: auth(token)).to_a.map do |deployment|
      Deployment.new(id: deployment[:id], environment: deployment[:environment], created_at: deployment[:created_at])
    end
  end

  # GitHub answers a spent rate limit with a 403, the status it also gives a
  # repo the token cannot read. Only the header tells them apart.
  def self.parse(response)
    if response.code.to_i == 403 && response["x-ratelimit-remaining"] == "0"
      raise RateLimited.new(status: 403, body: response.body)
    end

    super
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
  private_class_method :repo_path, :base_url, :auth, :parse
end
