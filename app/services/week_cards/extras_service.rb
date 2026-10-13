module WeekCards
  # The facts around a week card's timeline: how long the builder has been at
  # it, who came to look, when they build, how much code moved, and what GitHub
  # counted (pull requests merged, releases, deploys, stars). Each is nil when
  # there is nothing to show, so the card leaves its cell out rather than print
  # a zero.
  class ExtrasService < ApplicationService
    Extras = Data.define(:building, :audience, :hours, :code, :repos)
    Building = Data.define(:since, :week)
    Audience = Data.define(:visitors, :visitors_before, :subscribers)
    Hours = Data.define(:counts, :peak_from, :peak_to)
    Code = Data.define(:additions, :deletions, :files, :languages)
    Repos = Data.define(:merged_prs, :releases, :deploys, :stars)

    # commits: the week's shown commits, from TallyService.
    attr_accessor :week_card, :commits
    attr_reader :extras

    validates :week_card, presence: true

    private

    def execute
      @extras = Extras.new(building: building, audience: audience, hours: hours, code: code, repos: repos)
    end

    def user
      week_card.user
    end

    def last_day
      week_card.week_start + 6
    end

    # Building since the date the builder set in Settings, or their first entry.
    def building
      since = user.building_since || user.entries.publicly_visible.minimum(:occurred_at)&.to_date
      return unless since && since <= last_day

      Building.new(since: since, week: ((last_day - since).to_i / 7) + 1)
    end

    def audience
      range = week_card.time_range
      count = visitors(range)
      subscribers = user.subscriptions.confirmed.where(confirmed_at: range).count
      return if count.zero? && subscribers.zero?

      Audience.new(visitors: count, visitors_before: visitors((range.begin - 7.days)...range.begin), subscribers: subscribers)
    end

    # Unique by hashed IP, as /admin and Pro analytics count them.
    def visitors(range)
      user.profile_views.where(viewed_at: range).distinct.count(:ip_hash)
    end

    # Commits by hour of day in the card's zone, and the busiest two hours.
    def hours
      return if commits.to_a.empty?

      counts = Array.new(24, 0)
      commits.each { |entry| counts[entry.occurred_at.in_time_zone(week_card.zone).hour] += 1 }
      peak = TallyService.peak_hour(counts)
      Hours.new(counts: counts, peak_from: peak, peak_to: (peak + 2) % 24)
    end

    def code
      measured = commits.to_a.select(&:stats_fetched_at)
      return if measured.empty?

      Code.new(additions: measured.sum { |entry| entry.additions.to_i }, deletions: measured.sum { |entry| entry.deletions.to_i },
               files: measured.sum { |entry| entry.files_changed.to_i }, languages: language_shares(measured))
    end

    # The five biggest languages by lines changed, as [name, percent].
    def language_shares(measured)
      totals = measured.each_with_object(Hash.new(0)) do |entry, sum|
        entry.languages.to_h.each { |language, lines| sum[language] += lines.to_i }
      end
      all = totals.values.sum
      return [] if all.zero?

      totals.sort_by { |_language, lines| -lines }.first(5).map { |language, lines| [ language, ((lines * 100.0) / all).round ] }
    end

    def repos
      releases = user.entries.publicly_visible.where(source: :github, entry_type: :released, occurred_at: week_card.time_range).count
      activities = activity_counts
      counts = Repos.new(merged_prs: activities["pull_request"].to_i, releases: releases,
                         deploys: activities["deployment"].to_i, stars: stars_gained)
      counts if counts.to_h.values.any?(&:positive?)
    end

    # The week's merged pull requests and deploys, by kind, on the repos the
    # builder still includes.
    def activity_counts
      GithubActivity.where(user_id: user.id, github_repo_id: user.github_repos.included_repos.select(:id),
                           occurred_at: week_card.time_range).group(:kind).count
    end

    # Each included repo's last count on or before Sunday, less its last count
    # before Monday (or its first in the week, for a repo seen this week).
    def stars_gained
      repo_ids = user.github_repos.included_repos.pluck(:id)
      counts = GithubRepoStarCount.where(github_repo_id: repo_ids, recorded_on: (week_card.week_start - 30)..last_day)
                                  .order(:recorded_on).group_by(&:github_repo_id)
      counts.values.sum do |rows|
        before = rows.select { |row| row.recorded_on < week_card.week_start }.last || rows.first
        [ rows.last.stars - before.stars, 0 ].max
      end
    end
  end
end
