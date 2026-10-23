# GitHub's REST API with a token that reads a builder's repos: their sign-in
# token, or an installation token for private repos picked in the App. Branches,
# commits and releases need Contents and Metadata read; pull requests and
# deployments each need their own read permission, and GitHub answers 403
# without it.
class GithubGateway < ApplicationGateway
  API_VERSION = "2022-11-28".freeze

  CommitFile = Data.define(:filename, :additions, :deletions)
  Release = Data.define(:id, :name, :tag_name, :html_url, :published_at, :author_login, :draft)
  PullRequest = Data.define(:id, :number, :title, :merged_at, :author_login)
  Deployment = Data.define(:id, :environment, :created_at)
  Branch = Data.define(:name, :sha)
  Commit = Data.define(:sha, :message, :authored_at, :html_url, :author_login, :author_email)

  PREVIEW_QUERY = <<~GRAPHQL.freeze
    query($owner: String!, $name: String!) {
      repository(owner: $owner, name: $name) { openGraphImageUrl usesCustomOpenGraphImage }
    }
  GRAPHQL

  # A repo's README as text; nil when it has none.
  def self.readme(full_name, token:)
    body = get("/repos/#{repo_path(full_name)}/readme", headers: auth(token))
    Base64.decode64(body[:content].to_s).force_encoding(Encoding::UTF_8).scrub
  rescue NotFound
    nil
  end

  # The picture a repo shows when it is shared, when its owner set one; nil
  # for the card GitHub draws itself. REST does not have it, GraphQL does.
  def self.preview_image(full_name, token:)
    owner, name = full_name.to_s.split("/", 2)
    body = post("/graphql", body: { query: PREVIEW_QUERY, variables: { owner: owner, name: name } }, headers: auth(token))
    repository = body.dig(:data, :repository)
    repository[:openGraphImageUrl] if repository&.dig(:usesCustomOpenGraphImage)
  end

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
