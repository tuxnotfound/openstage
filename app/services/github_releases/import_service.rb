module GithubReleases
  # Brings a builder's GitHub releases onto their page as "released" entries,
  # from the included repos they committed to lately. A release is theirs on a
  # repo they own, or when they published it.
  class ImportService < ApplicationService
    ACTIVE_WITHIN = 8.weeks
    SINCE = 1.year

    # tokens: a GithubExtras::Tokens for this user.
    attr_accessor :user, :tokens
    attr_reader :imported

    validates :user, :tokens, presence: true

    private

    def execute
      @imported = 0
      active_repos.each do |repo|
        GithubGateway.releases(repo.full_name, token: tokens.for(repo)).each { |release| import(repo, release) }
      rescue ApplicationGateway::Unauthorized, ApplicationGateway::RateLimited
        break
      rescue ApplicationGateway::NotFound
        next
      end
    end

    def active_repos
      names = user.entries.where(source: :github, entry_type: :shipped, occurred_at: ACTIVE_WITHIN.ago..).select(:repo_name)
      user.github_repos.included_repos.where(full_name: names)
    end

    def import(repo, release)
      published_at = release.published_at && Time.zone.parse(release.published_at.to_s)
      return if release.draft || published_at.nil? || published_at < SINCE.ago || !theirs?(repo, release)

      entry = user.entries.find_or_initialize_by(external_id: "release-#{release.id}")
      return unless entry.new_record? && !dismissed.include?(entry.external_id)

      # Never link to a private repo.
      entry.update!(entry_type: :released, source: :github, title: title(repo, release), occurred_at: published_at,
                    url: repo.private_repo? ? nil : release.html_url, repo_name: repo.full_name)
      @imported += 1
    rescue ActiveRecord::RecordNotUnique
      # Another run imported it at the same moment.
      nil
    end

    def theirs?(repo, release)
      repo.owned_by_user? || release.author_login.to_s.casecmp?(user.github_username.to_s)
    end

    # A release named only by its tag says little alone, so the repo comes first.
    def title(repo, release)
      name = release.name.to_s.strip
      name.present? && name != release.tag_name ? name.truncate(200) : "#{repo.name} #{release.tag_name}"
    end

    # Deleted from the page means never imported again, as for commits.
    def dismissed
      @dismissed ||= DismissedCommit.where(user_id: user.id).pluck(:sha).to_set
    end
  end
end
