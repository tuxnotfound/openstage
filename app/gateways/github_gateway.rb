# GitHub's REST API with a token that reads a builder's repos: their sign-in
# token, or an installation token for private repos picked in the App. Branches
# and commits need Contents and Metadata read; pull requests need their own read
# permission, and GitHub answers 403 without it.
class GithubGateway < ApplicationGateway
  API_VERSION = "2022-11-28".freeze

  Branch = Data.define(:name, :sha)
  Commit = Data.define(:sha, :message, :authored_at, :html_url, :author_login, :author_email)

  # A repo's branches with the commit each one points at. One page of 100, which
  # covers any repo a builder works in by hand.
  def self.branches(full_name, token:)
    get("/repos/#{repo_path(full_name)}/branches", query: { per_page: 100 }, headers: auth(token)).to_a.map do |branch|
      Branch.new(name: branch[:name], sha: branch.dig(:commit, :sha))
    end
  end

  # The commits head has that base does not, oldest first. GitHub lists at most
  # 250, plenty for one branch's own work.
  def self.commits_ahead(full_name, base:, head:, token:)
    basehead = "#{ERB::Util.url_encode(base)}...#{ERB::Util.url_encode(head)}"
    get("/repos/#{repo_path(full_name)}/compare/#{basehead}", headers: auth(token))[:commits].to_a.map do |commit|
      Commit.new(sha: commit[:sha], message: commit.dig(:commit, :message).to_s,
                 authored_at: Time.zone.parse(commit.dig(:commit, :author, :date).to_s),
                 html_url: commit[:html_url], author_login: commit.dig(:author, :login),
                 author_email: commit.dig(:commit, :author, :email))
    end
  end

  # The numbers of the merged pull requests a commit belongs to.
  def self.merged_pull_numbers(full_name, sha, token:)
    pulls = get("/repos/#{repo_path(full_name)}/commits/#{ERB::Util.url_encode(sha)}/pulls", headers: auth(token)).to_a
    pulls.select { |pull| pull[:merged_at].present? }.map { |pull| pull[:number] }
  end

  # The SHAs of a pull request's commits, up to 100.
  def self.pull_commit_shas(full_name, number, token:)
    get("/repos/#{repo_path(full_name)}/pulls/#{number.to_i}/commits", query: { per_page: 100 }, headers: auth(token))
      .to_a.map { |commit| commit[:sha] }
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
