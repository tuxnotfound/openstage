namespace :privacy do
  desc "Privatise entries from private repos. Usage: rake 'privacy:privatize_repos[owner/repo owner/other]' or no args to sweep every known private repo"
  task :privatize_repos, [ :repos ] => :environment do |_t, args|
    names = args[:repos].to_s.split(/[\s,]+/).reject(&:blank?)
    names += Array(args.extras).flat_map { |e| e.to_s.split(/[\s,]+/) }
    names = names.reject(&:blank?).uniq

    names = GithubRepo.where(private_repo: true).distinct.pluck(:full_name) if names.empty?

    if names.empty?
      puts "No private repos known yet. Run a sync first, or pass repo names explicitly."
      next
    end

    puts "Privatising entries for: #{names.join(', ')}"

    scope = Entry.where(source: :github, repo_name: names, hidden: false)
    affected = scope.group(:repo_name).count
    count = scope.update_all(hidden: true, url: nil)

    affected.each { |repo, n| puts "  #{repo}: #{n}" }
    puts "Privatised #{count} #{'entry'.pluralize(count)}."
  end

  desc "Report visible entries from private repos nobody opted into, without changing anything"
  task audit: :environment do
    private_names = GithubRepo.where(private_repo: true, included: false).distinct.pluck(:full_name)
    leaked = Entry.where(source: :github, repo_name: private_names, hidden: false)
                  .group(:repo_name).count

    if leaked.empty?
      puts "Clean: no public entries from known private repos."
    else
      puts "LEAKED public entries by repo:"
      leaked.each { |repo, n| puts "  #{repo}: #{n}" }
    end

    puts "Known private repos: #{private_names.size}"
  end
end
