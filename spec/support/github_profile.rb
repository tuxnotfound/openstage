# A GitHub user's public work as GithubProfileGateway returns it, for the
# preview's specs. Include it in a spec that needs it.
module GithubProfileData
  def github_profile(login: "ada", repos: [ github_profile_repo ], private_contributions: 0)
    GithubProfileGateway::Profile.new(id: "U_ada", login: login, name: "Ada Lovelace", avatar_url: "https://avatars.githubusercontent.com/u/2",
                                      bio: "Engines and notes", website: "https://ada.example", repos: repos,
                                      private_contributions: private_contributions)
  end

  def github_recent_repo(name: "notes", description: "Notes on the engine", homepage: nil, language: "Ruby", updated_at: Time.utc(2024, 4, 9))
    GithubProfileGateway::RecentRepo.new(full_name: "ada/#{name}", name: name, description: description, url: "https://github.com/ada/#{name}",
                                         homepage: homepage, language: language, updated_at: updated_at)
  end

  # days: commits by Date.
  def github_profile_repo(name: "engine", days: { Date.current - 3 => 4 }, homepage: nil, archived: false, description: "The analytical engine")
    GithubProfileGateway::Repo.new(full_name: "ada/#{name}", name: name, description: description, url: "https://github.com/ada/#{name}",
                                   homepage: homepage, archived: archived, days: days)
  end

  def github_profile_commit(repo: "ada/engine", title: "Add the mill", at: 2.days.ago)
    GithubProfileGateway::Commit.new(repo: repo, title: title, authored_at: at, url: "https://github.com/#{repo}/commit/abc")
  end
end
