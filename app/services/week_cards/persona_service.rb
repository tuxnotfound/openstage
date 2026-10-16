module WeekCards
  # Names the week from its rarest fact, for the Star Chart: a title, a
  # tagline and the evidence. The rules run in order and the first that holds
  # names the week; commit hours are only the fallback. Ported word for word
  # from doc/week_cards/mocks/star_chart.dc.html:
  #   1. a record week: The Record Breaker (needs a best week to beat);
  #   2. seven days in a row or more: The Marathoner;
  #   3. commits after two quiet weeks or more: The Comeback Kid;
  #   4. two launches or more: The Serial Shipper;
  #   5. one launch, no commits, two posts or more: The Headliner;
  #   6. one launch: The Launcher;
  #   7. posts and no commits: The Storyteller;
  #   8. by commit hours: The Nighthawk, The Night Owl, The Early Bird,
  #      The Daylighter, else The Double Shift;
  #   9. nothing at all: The Stargazer.
  # The evidence never says "down from".
  class PersonaService < ApplicationService
    # extra: a second clause, printed only when the whole line fits. hours:
    # the window an hour persona is read from, [from, to) on a clock that runs
    # past 24, or nil.
    Persona = Data.define(:title, :tagline, :evidence, :extra, :hours)
    NUMBERS = %w[no one two three four five six seven eight nine].freeze
    # Windows on a 24-hour clock, from inclusive to exclusive; one may run
    # past midnight.
    HOURS = [
      [ "The Nighthawk", "Most of your building happens after 10 PM", 22, 4, 0.5, "AFTER 10 PM" ],
      [ "The Night Owl", "Most of your building happens after dark", 19, 4, 0.5, "BETWEEN 7 PM AND 4 AM" ],
      [ "The Early Bird", "A good share of your building lands before 9 AM", 4, 9, 0.3, "BETWEEN 4 AM AND 9 AM" ],
      [ "The Daylighter", "Most of your building happens in the working day", 9, 18, 0.6, "BETWEEN 9 AM AND 6 PM" ]
    ].freeze

    # tally: the week, from TallyService. previous: last week's commits.
    # history: the work before the week, from HistoryService.
    attr_accessor :tally, :previous, :history
    attr_reader :persona

    validates :tally, :history, presence: true

    private

    def execute
      @persona = record || marathon || comeback || serial || headliner || launcher || storyteller || hours || stargazer
    end

    def record
      best = history.best_week
      return unless commits.positive? && best && commits > best

      named("The Record Breaker", "Your most commits in a single week", "#{commits} COMMITS, THE OLD BEST WAS #{best}")
    end

    # The streak may start in an earlier week.
    def marathon
      days = [ history.streak.to_i, commit_run ].max
      return if days < 7

      named("The Marathoner", "You built every day for a week or more", "#{days} DAYS IN A ROW", clause)
    end

    def comeback
      quiet = history.quiet_weeks.to_i
      return unless commits.positive? && quiet >= 2

      named("The Comeback Kid", "Back to building after a quiet stretch", "BACK AFTER #{(NUMBERS[quiet] || quiet.to_s).upcase} QUIET WEEKS",
              "#{plural(commits, 'COMMIT')} IN #{plural(commit_days.size, 'DAY')}")
    end

    def serial
      return if launches.size < 2

      times = { 1 => "ONCE", 2 => "TWICE" }.fetch(launches.size, "#{launches.size} TIMES")
      named("The Serial Shipper", "You launched more than once in one week",
              "SHIPPED #{times} IN #{launches.last - launches.first + 1} DAYS", clause)
    end

    def headliner
      return unless launches.size == 1 && commits.zero? && posts.size >= 2

      named("The Headliner", "You launched, then spent the week talking about it", "SHIPPED #{day_name(launches.first)}", posts_clause)
    end

    # The commits before the launch day, when there were any.
    def launcher
      return unless launches.size == 1

      launch = launches.first
      before = tally.days.first(launch).sum(&:total)
      tagline = "You put something out into the world"
      return named("The Launcher", tagline, "SHIPPED #{day_name(launch)}", commits.positive? ? clause : posts_clause) if before.zero?

      named("The Launcher", tagline, "SHIPPED #{day_name(launch)}, AFTER #{plural(before, 'COMMIT')} IN " \
                                       "#{plural(tally.days.first(launch).count { |day| day.total.positive? }, 'DAY')}")
    end

    def storyteller
      return unless commits.zero? && posts.any?

      named("The Storyteller", "No commits this week, but you wrote about the work", plural(posts.size, "POST"), so_far)
    end

    def hours
      return if commits.zero?

      HOURS.each do |title, tagline, from, to, share, words|
        count = in_window(from, to)
        next if count < share * commits

        return named(title, tagline, landed(count, words), nil, [ from, to < from ? to + 24 : to ])
      end
      named("The Double Shift", "You build by day and again after dark",
              "#{plural(in_window(9, 19), 'COMMIT')} BY DAY · #{in_window(19, 4)} AFTER 7 PM")
    end

    def stargazer
      named("The Stargazer", "A quiet week with nothing logged", "A CLEAR SKY", so_far)
    end

    def named(title, tagline, evidence, extra = nil, hours = nil)
      Persona.new(title: title, tagline: tagline, evidence: evidence, extra: extra.presence, hours: hours)
    end

    def commits
      @commits ||= tally.days.sum(&:total)
    end

    # "74 COMMITS, UP FROM 32" when up on last week, else "32 COMMITS".
    def clause
      return "" if commits.zero?
      return "#{commits} COMMITS, UP FROM #{previous}" if previous.to_i.positive? && commits > previous

      plural(commits, "COMMIT")
    end

    # "THEN 3 POSTS" when every post came after the launch.
    def posts_clause
      return "" if posts.empty?

      posts.all? { |day| day > launches.first } ? "THEN #{plural(posts.size, 'POST')}" : plural(posts.size, "POST")
    end

    def so_far
      "#{(history.commits_before + commits).to_fs(:delimited)} COMMITS SO FAR"
    end

    def landed(count, window)
      return "YOUR ONE COMMIT LANDED #{window}" if commits == 1
      return "#{count == 2 ? 'BOTH COMMITS' : 'ONE OF TWO COMMITS'} LANDED #{window}" if commits == 2

      "#{count} OF #{commits} COMMITS #{window}"
    end

    # Days of the week, by index, whose headline is a launch or a post.
    def launches
      @launches ||= days_of_kind("shipped")
    end

    def posts
      @posts ||= days_of_kind("published")
    end

    def days_of_kind(kind)
      tally.days.each_index.select { |i| tally.days[i].headline&.kind == kind }
    end

    def commit_days
      tally.days.select { |day| day.total.positive? }
    end

    def commit_run
      tally.days.chunk_while { |a, b| a.total.positive? && b.total.positive? }.select { |run| run.first.total.positive? }.map(&:size).max || 0
    end

    def in_window(from, to)
      tally.days.sum do |day|
        day.hours.sum { |hour, projects| (from < to ? hour >= from && hour < to : hour >= from || hour < to) ? projects.values.sum : 0 }
      end
    end

    def day_name(index)
      tally.days[index].date.strftime("%A").upcase
    end

    def plural(count, word)
      "#{count.to_fs(:delimited)} #{count == 1 ? word : "#{word}S"}"
    end
  end
end
