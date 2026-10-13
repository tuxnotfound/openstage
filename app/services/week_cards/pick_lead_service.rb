module WeekCards
  # What the week card leads with, set large above the days: one day's headline,
  # or the week's numbers. The builder's pick comes first. Then the builder's
  # own words: a launch before other work, then the busier day. Then a launch
  # the card found by itself. Lines the card writes ("Posted on X", a count, an
  # entry's title) never lead over the builder's words, and without those words
  # or a launch, the week's numbers lead: "74 commits in 3 projects".
  class PickLeadService < ApplicationService
    # fly says what the lead is in plain words ("Shipped on Thursday, Oct 8"),
    # or only the date for a line the card wrote. date is nil for the week.
    Lead = Data.define(:date, :text, :kind, :fly, :generated)

    # tally: the week, from TallyService.
    attr_accessor :week_card, :tally
    attr_reader :lead

    validates :week_card, :tally, presence: true

    private

    def execute
      @lead = picked || written || launched || numbers || posted || quiet
    end

    def picked
      day = headlined.find { |candidate| candidate.date == week_card.lead_on }
      lead_from(day) if day
    end

    def written
      own = headlined.select { |day| day.headline.source == :builder && words(day).present? }
      day = busiest(of_kind(own, "shipped")) || busiest(of_kind(own, "built")) || of_kind(own, "published").first
      lead_from(day) if day
    end

    def launched
      day = busiest(of_kind(headlined, "shipped"))
      lead_from(day) if day
    end

    def numbers
      return unless tally.totals.commits.positive?

      counts = tally.projects.select(&:shown).map { |project| [ project.name, project.n ] }
      Lead.new(date: nil, text: TallyService.count_line(counts), kind: "built", fly: "Built this week", generated: true)
    end

    def posted
      day = of_kind(headlined, "published").first
      lead_from(day) if day
    end

    def quiet
      Lead.new(date: nil, text: "A quiet week", kind: nil, fly: "Week #{week_card.week_start.cweek}", generated: true)
    end

    # The days with something to say. Without headlines the card says only what
    # it counted, so the numbers lead.
    def headlined
      week_card.shows?("headlines") ? tally.days.select(&:headline) : []
    end

    def of_kind(days, kind)
      days.select { |day| day.headline.kind == kind }
    end

    # Most commits, and the later day of a tie.
    def busiest(days)
      days.max_by { |day| [ day.total, day.date ] }
    end

    def words(day)
      CardText.clean(day.headline.text)
    end

    def lead_from(day)
      generated = day.headline.source == :count || words(day).empty?
      date = day.date.strftime("%A, %b %-d")
      Lead.new(date: day.date, text: words(day).presence || stand_in(day), kind: day.headline.kind,
               fly: generated ? date : "#{day.headline.kind.capitalize} on #{date}", generated: generated)
    end

    # Words that were only emoji: what the day was, so it never reads as empty.
    def stand_in(day)
      return day.headline.kind.capitalize unless day.headline.kind == "built"
      return "Built" unless day.total.positive?

      TallyService.count_line(day.segments.map { |segment| [ segment.project, segment.n ] })
    end
  end
end
