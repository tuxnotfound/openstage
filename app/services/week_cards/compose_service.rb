module WeekCards
  # Everything one week card shows: the week tallied (TallyService), the same
  # tally for the week before so the card can say what changed, what the card
  # leads with (PickLeadService), and the facts around the days
  # (ExtrasService). Public entries only.
  class ComposeService < ApplicationService
    Card = Data.define(:week_card, :user, :label, :dates, :days, :projects, :totals, :best_run, :streak,
                       :previous, :lead, :extras, :draft)

    attr_accessor :week_card
    attr_reader :card

    validates :week_card, presence: true

    private

    def execute
      tally = run(TallyService.new(week_card: week_card))&.tally
      lead = run(PickLeadService.new(week_card: week_card, tally: tally))&.lead
      extras = run(ExtrasService.new(week_card: week_card, commits: tally&.commits || []))&.extras
      return unless tally && lead && extras

      @card = Card.new(
        week_card: week_card, user: week_card.user, label: "Week #{week_card.week_start.cweek}",
        dates: date_range_label, days: tally.days, projects: tally.projects, totals: tally.totals,
        best_run: tally.best_run, streak: current_week? ? week_card.user.public_activity_streak : nil,
        previous: previous_tally, lead: lead, extras: extras, draft: draft(tally)
      )
    end

    def run(service)
      service.call
      service if absorb_errors(service)
    end

    # The week before, counted the same way: same projects, same time zone,
    # and the headlines the builder wrote on that week's own card.
    def previous_tally
      previous = WeekCard.find_or_initialize_by(user: week_card.user, week_start: week_card.week_start - 7)
      previous.hidden_projects = week_card.hidden_projects
      previous.time_zone = week_card.time_zone
      run(TallyService.new(week_card: previous))&.tally
    end

    # A starting point for the post that goes out with the card, built from the
    # card's own facts. The builder rewrites it.
    def draft(tally)
      lines = tally.days.filter_map(&:headline).reject { |headline| headline.source == :count }
                   .map { |headline| "- #{headline.text}" }
      summary = "Week #{week_card.week_start.cweek}: #{tally.totals.commits} #{'commit'.pluralize(tally.totals.commits)} " \
                "on #{tally.totals.active_days} of 7 days."
      goal = week_card.next_goal ? [ "Next: #{week_card.next_goal}" ] : []
      ([ summary ] + lines + goal).join("\n")
    end

    def current_week?
      week_card.days.include?(Date.current)
    end

    def date_range_label
      first, last = week_card.week_start, week_card.week_start + 6
      start = first.strftime("%b %-d")
      finish = first.month == last.month ? last.strftime("%-d") : last.strftime("%b %-d")
      "#{start} – #{finish}, #{last.year}"
    end
  end
end
