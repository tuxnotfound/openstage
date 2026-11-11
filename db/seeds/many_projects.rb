# A builder with hundreds of repos, shaped like the first stranger whose stage
# grew past what its cards could hold (2026-11-10): 394 public repos, two busy
# ones, eight in the tens, about ninety with a handful of commits, and nearly
# three hundred touched once or twice in the same week five weeks ago; 108
# live on six sites; most with no description. Every name, site and word here
# is made up. Run again, it starts over, so its dates follow today.
#
#   bin/rails db:seed, then open /manyrepos
module Seeds
  class ManyProjects
    USERNAME = "manyrepos".freeze
    OWNER = "many-repos-demo".freeze
    TOPICS = %w[sauna fire churn gig rent invoice tariff battery solar coffee commute garden pantry rowing sleep hydration mortgage
                lease payroll freelance subscription warranty repair durable laundry heating cooling bike transit parking grocery
                insurance tuition pension].freeze
    KINDS = %w[calc math r d hs cpp cli site notes ledger planner cost].freeze
    SITES = %w[https://flatfee.example https://www.fireplan.example https://pastacost.example https://sidegigs.example
               https://selfhacked.example https://www.buyonce.example].freeze
    TITLES = [ "docs: worked example with the figures", "fix: rounding in the monthly view", "build: docs site config", "README: usage and install",
               "test: edge cases for zero input", "feat: CSV export", "refactor: split the calculator", "demo: ledger printer",
               "chore: tidy the examples", "feat: compare two plans side by side" ].freeze
    # Initials on a disc, inline, so the page fetches no one's picture.
    AVATAR = "data:image/svg+xml,#{ERB::Util.url_encode('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 72">' \
                                                       '<rect width="72" height="72" fill="#2f6ee0"/><text x="36" y="45" font-family="sans-serif" ' \
                                                       'font-size="26" font-weight="700" fill="#fff" text-anchor="middle">DB</text></svg>')}".freeze
    DESCRIPTIONS = [ "Cost per use for things you buy once.", "Break-even math, stdlib only, no cloud.", "A small calculator behind one of our posts.",
                     "Monthly cost against a flat fee, with the figures.", "Hourly rate after fees, taxes and the hours nobody counts." ].freeze

    def call
      random = Random.new(2026)
      user = builder
      user.entries.delete_all
      user.github_repos.delete_all
      repos = names(random).each_with_index.map { |name, i| repo_row(user, name, i, random) }
      GithubRepo.insert_all!(repos)
      Entry.insert_all!(repos.first(393).each_with_index.flat_map { |repo, i| commit_rows(user, repo[:full_name], i, random) })
      puts "Seeded @#{USERNAME}: #{user.github_repos.count} repos, #{user.entries.count} commits. Open /#{USERNAME}."
    end

    private

    def builder
      User.find_or_initialize_by(username: USERNAME).tap do |user|
        user.update!(github_uid: "seed-#{USERNAME}", github_username: OWNER, display_name: "Demo Builder",
                     bio: "Calculators behind the posts on six small sites. Made-up data for a stage with hundreds of repos.",
                     avatar_url: AVATAR, website_url: SITES.first,
                     building_since: Date.new(2026, 9, 4), deleted_at: nil)
      end
    end

    # 394 distinct names: every topic with every kind, shuffled.
    def names(random)
      TOPICS.product(KINDS).map { |topic, kind| "#{topic}-#{kind}" }.shuffle(random: random).first(394)
    end

    # 108 live, spread over the six sites; 148 with a description; three archived.
    def repo_row(user, name, index, random)
      { user_id: user.id, github_repo_id: 9_000_000 + index, name: name, full_name: "#{OWNER}/#{name}", url: "https://github.com/#{OWNER}/#{name}",
        description: (DESCRIPTIONS.sample(random: random) if index % 8 < 3), homepage: (SITES[index % SITES.size] if index % 11 < 3 || index < 6),
        archived: [ 200, 250, 300 ].include?(index), included: true, default_branch: "main", private_repo: false, stars_count: 0 }
    end

    def commit_rows(user, repo, index, random)
      count, days = shape(index, random)
      Array.new(count) do |n|
        { user_id: user.id, entry_type: "shipped", source: "github", repo_name: repo, external_id: "seed-#{repo}-#{n}",
          title: TITLES.sample(random: random), occurred_at: days.sample(random: random).days.ago - random.rand(0..86_000).seconds }
      end
    end

    # How many commits a repo has, and the days ago they fall on, by its rank.
    def shape(index, random)
      case index
      when 0 then [ 116, (5..35).to_a ]
      when 1 then [ 103, (3..33).to_a ]
      when 2..9 then [ random.rand(9..13), (6..40).to_a ]
      when 10..99 then [ random.rand(3..7), (14..60).to_a ]
      else [ random.rand(1..2), (33..38).to_a ]
      end
    end
  end
end

Seeds::ManyProjects.new.call
