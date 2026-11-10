module PageViews
  # One view of a page on Openstage, a builder's stage or a project's page,
  # sent by the page itself once it runs in a browser (page_view_controller.js),
  # with the ticket the server put in it (PageViewTicket). A client that never
  # runs the page, as crawlers mostly do not, counts none. Never the builder's
  # own view nor a bot's: neither gets a ticket, and a bot's request is refused
  # here too. The IP is hashed with the day and a key (VisitorHash).
  class RecordService < ApplicationService
    # ticket: what the page sent; country: the CF-IPCountry header.
    attr_accessor :ticket, :ip, :user_agent, :country
    attr_reader :view

    validates :ticket, :ip, presence: true
    validate :from_a_person, :issued_by_openstage

    private

    def execute
      @view = views.create!(viewed_at: Time.current, referrer: page["f"], ip_hash: VisitorHash.of(ip), country: country.presence)
    end

    def from_a_person
      errors.add(:user_agent, "is a bot's") if BotDetector.bot?(user_agent)
    end

    def issued_by_openstage
      errors.add(:ticket, "is not one Openstage issued, or it expired") unless user
    end

    def page
      @page ||= PageViewTicket.read(ticket) || {}
    end

    def user
      @user ||= User.active.find_by(id: page["u"]) if page["u"]
    end

    # A project's page counts as that project's view, the stage as the builder's.
    def views
      page["r"] ? user.project_views.where(repo_name: page["r"]) : user.profile_views
    end
  end
end
