# Any GitHub user's public work, read with Openstage's own token, for the
# stage a visitor previews before signing in (Previews::BuildService). The
# token needs no scope: GitHub then answers with public repos alone, and a
# private one is dropped here all the same, should a token that reads more
# ever be set.
class GithubProfileGateway < ApplicationGateway
  # GitHub answers a span's commits as one node per day per repo, at most 100
  # to a page, so a span under 100 days never needs a second page. A year is
  # read as several spans.
  SPAN_DAYS = 90
  # The busiest repos of each span; GitHub allows 100.
  REPOS_PER_SPAN = 25

  # days: commits by Date.
  Repo = Data.define(:full_name, :name, :description, :url, :homepage, :archived, :days)
  # id: GitHub's node id, which the commits' author filter takes.
  # private_contributions: what GitHub counts of their private work in the
  # spans, which it shares only when they chose to show it on their profile.
  Profile = Data.define(:id, :login, :name, :avatar_url, :bio, :website, :repos, :private_contributions)
  # A public repo they own, as its last update left it.
  RecentRepo = Data.define(:full_name, :name, :description, :url, :homepage, :language, :updated_at)
  Commit = Data.define(:repo, :title, :authored_at, :url)

  PROFILE_QUERY = <<~GRAPHQL.freeze
    query($login: String!, $from: DateTime!, $to: DateTime!) {
      user(login: $login) {
        id login name avatarUrl bio websiteUrl
        contributionsCollection(from: $from, to: $to) {
          restrictedContributionsCount
          commitContributionsByRepository(maxRepositories: #{REPOS_PER_SPAN}) {
            repository { nameWithOwner name description url homepageUrl isArchived isPrivate }
            contributions(first: 100) { nodes { occurredAt commitCount } }
          }
        }
      }
    }
  GRAPHQL

  RECENT_REPOS_QUERY = <<~GRAPHQL.freeze
    query($login: String!, $count: Int!) {
      user(login: $login) {
        repositories(first: $count, privacy: PUBLIC, ownerAffiliations: OWNER, isFork: false,
                     orderBy: { field: PUSHED_AT, direction: DESC }) {
          nodes { nameWithOwner name description url homepageUrl pushedAt isPrivate isArchived primaryLanguage { name } }
        }
      }
    }
  GRAPHQL

  # Whether a token is set; previews are off without one.
  def self.configured?
    token.present?
  end

  # The user's profile and their commits per repo and day from from to to,
  # both Dates. Raises NotFound for a login that is no GitHub user, an
  # organization included.
  def self.profile(login, from:, to:)
    users = in_parallel(spans(from, to)) do |first, last|
      query(PROFILE_QUERY, { login: login, from: first.beginning_of_day.utc.iso8601, to: last.end_of_day.utc.iso8601 })[:user]
    end
    user = users.first || raise(NotFound.new(status: 404))
    Profile.new(id: user[:id], login: user[:login], name: user[:name].presence, avatar_url: user[:avatarUrl],
                bio: user[:bio].presence, website: user[:websiteUrl].presence, repos: repos(users),
                private_contributions: users.compact.sum { |each| each.dig(:contributionsCollection, :restrictedContributionsCount).to_i })
  end

  # Up to count public repos they own, not forks, archived ones left out,
  # the last updated first.
  def self.recent_repos(login, count:)
    nodes = query(RECENT_REPOS_QUERY, { login: login, count: count }).dig(:user, :repositories, :nodes)
    Array(nodes).reject { |repo| repo[:isPrivate] || repo[:isArchived] }.map do |repo|
      RecentRepo.new(full_name: repo[:nameWithOwner], name: repo[:name], description: repo[:description].presence, url: repo[:url],
                     homepage: repo[:homepageUrl].presence, language: repo.dig(:primaryLanguage, :name), updated_at: Time.iso8601(repo[:pushedAt]))
    end
  end

  # The latest commits author_id made to each repo's default branch, newest
  # first, up to per_repo from each.
  def self.commits(author_id, full_names, per_repo:)
    variables = full_names.each_with_index.reduce({ id: author_id }) do |all, (full_name, i)|
      owner, name = full_name.split("/", 2)
      all.merge("o#{i}": owner, "n#{i}": name)
    end
    data = query(commits_query(full_names.size, per_repo), variables)
    commits = full_names.each_index.flat_map { |i| repo_commits(data[:"r#{i}"]) }
    commits.sort_by(&:authored_at).reverse
  end

  # [first, last] Dates, each span at most SPAN_DAYS long.
  def self.spans(from, to)
    from.step(to, SPAN_DAYS).map { |first| [ first, [ first + SPAN_DAYS - 1, to ].min ] }
  end

  # GitHub takes about as long to count one span as several in one query, so
  # each span is its own request, all at once: a busy year reads in under
  # two seconds rather than four. Each thread runs in the app's executor, the
  # caller lets them load code while it waits, and a thread's error is raised
  # in the caller by value rather than printed.
  def self.in_parallel(spans, &read)
    threads = spans.map do |span|
      Thread.new do
        Thread.current.report_on_exception = false
        Rails.application.executor.wrap { read.call(*span) }
      end
    end
    ActiveSupport::Dependencies.interlock.permit_concurrent_loads { threads.map(&:value) }
  end

  def self.commits_query(count, per_repo)
    repos = (0...count).map do |i|
      "r#{i}: repository(owner: $o#{i}, name: $n#{i}) { nameWithOwner isPrivate defaultBranchRef { target { ... on Commit " \
        "{ history(first: #{per_repo}, author: { id: $id }) { nodes { messageHeadline authoredDate url } } } } } }"
    end
    params = (0...count).map { |i| "$o#{i}: String!, $n#{i}: String!" }.join(", ")
    "query($id: ID!, #{params}) { #{repos.join(' ')} }"
  end

  # GraphQL answers 200 with errors and no data when it cannot run a query,
  # and 200 with errors beside the data for a field it could not resolve, such
  # as an unknown login, whose field is then null.
  def self.query(text, variables)
    body = post("/graphql", body: { query: text, variables: variables }, headers: auth)
    data = body[:data]
    return data if data

    errors = Array(body[:errors])
    raise RateLimited.new(status: 200, body: errors) if errors.any? { |error| error[:type] == "RATE_LIMITED" }

    raise Error.new(errors.filter_map { |error| error[:message] }.join("; ").presence, status: 200, body: errors)
  end

  # Each repo's days summed over the spans, one user's answer per span,
  # public repos alone.
  def self.repos(users)
    found = {}
    users.compact.each do |user|
      Array(user.dig(:contributionsCollection, :commitContributionsByRepository)).each do |entry|
        info = entry[:repository]
        next if info[:isPrivate]

        repo = found[info[:nameWithOwner]] ||= new_repo(info)
        Array(entry.dig(:contributions, :nodes)).each { |node| add_day(repo.days, node) }
      end
    end
    found.values
  end

  def self.new_repo(info)
    Repo.new(full_name: info[:nameWithOwner], name: info[:name], description: info[:description].presence, url: info[:url],
             homepage: info[:homepageUrl].presence, archived: info[:isArchived], days: Hash.new(0))
  end

  # GitHub stamps a day at its midnight in the user's own zone, so
  # 2026-11-08T08:00:00Z is 8 November on the US west coast. Twelve hours on
  # lands inside that day for any zone from UTC-12 to UTC+12.
  def self.add_day(days, node)
    day = (Time.iso8601(node[:occurredAt]) + 12.hours).utc.to_date
    days[day] += node[:commitCount].to_i
  end

  def self.repo_commits(repo)
    return [] if repo.nil? || repo[:isPrivate]

    Array(repo.dig(:defaultBranchRef, :target, :history, :nodes)).map do |node|
      Commit.new(repo: repo[:nameWithOwner], title: node[:messageHeadline].to_s, authored_at: Time.iso8601(node[:authoredDate]),
                 url: node[:url])
    end
  end

  def self.base_url
    "https://api.github.com"
  end

  def self.token
    Rails.configuration.x.github_profile_token
  end

  def self.auth
    { "Authorization" => "Bearer #{token}" }
  end
  private_class_method :spans, :in_parallel, :commits_query, :query, :repos, :new_repo, :add_day, :repo_commits,
                       :base_url, :token, :auth
end
