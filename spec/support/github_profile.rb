# A GitHub user's public work as GithubProfileGateway returns it, for the
# preview's specs. Include it in a spec that needs it.
module GithubProfileData
  def github_profile(login: "ada", repos: [ github_profile_repo ])
    GithubProfileGateway::Profile.new(id: "U_ada", login: login, name: "Ada Lovelace", avatar_url: "https://avatars.githubusercontent.com/u/2",
                                      bio: "Engines and notes", website: "https://ada.example", repos: repos)
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
