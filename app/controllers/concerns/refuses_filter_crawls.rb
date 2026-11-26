# A crawler that ignores robots.txt gets no filtered view of a stage or of a
# project's page: 403, with no body, before any query or view counting runs.
# The chart's switches are links that combine without end, which is why
# robots.txt disallows them for every agent; Meta's crawler followed them
# anyway, one 2-second page every 2 seconds for a week (2026-11-26). A person
# sees no change, and a crawler keeps the page itself and its list's ?page=,
# ?sort= and ?live=.
module RefusesFilterCrawls
  extend ActiveSupport::Concern

  # The params public/robots.txt disallows (its /*?range=, /*?projects= and
  # /*?show= lines, and their & forms): change the two together.
  FILTER_PARAMS = %w[range projects show].freeze

  # The link previews robots.txt's second group names. Each reads one URL a
  # person shared, for its card, so a filtered link pasted in a message keeps
  # its card on an app that ignores robots.txt for shared links. BotDetector
  # counts them as bots, since a view of theirs is no person's.
  LINK_PREVIEWS = %w[facebookexternalhit twitterbot linkedinbot slackbot discordbot telegrambot whatsapp].freeze

  included do
    prepend_before_action :refuse_filter_crawl
  end

  private

  def refuse_filter_crawl
    head :forbidden if filter_crawl?
  end

  # A refusal needs an agent that names a crawler. A client that sends none
  # counts no view (BotDetector), and still gets its page: no name is no proof.
  def filter_crawl?
    return false unless FILTER_PARAMS.any? { |name| params.key?(name) }

    agent = request.user_agent.to_s.downcase
    agent.present? && BotDetector.bot?(agent) && LINK_PREVIEWS.none? { |name| agent.include?(name) }
  end
end
