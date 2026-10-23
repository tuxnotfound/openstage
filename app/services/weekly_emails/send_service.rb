module WeeklyEmails
  # One builder's two weekly emails (F2). The builder gets their week, ready to
  # review, with one link to its week card; their confirmed subscribers get
  # the week itself, and a project's followers that project's week. A quiet
  # week (fewer than three things) sends neither, a quiet project sends its
  # followers nothing, and nothing is ever posted for anyone.
  class SendService < ApplicationService
    # Shorter than a week, so a run that starts a little early next week still sends.
    RESEND_AFTER = 6.days
    # Commits, shipped and published entries: fewer is a quiet week.
    WORTH_SENDING = 3

    attr_accessor :user
    attr_reader :builder_mailed, :digests_sent

    validates :user, presence: true

    private

    def execute
      @builder_mailed = false
      @digests_sent = 0
      return if quiet?

      mail_builder
      mail_subscribers
    end

    # Judged on the week the emails show, the Week view so far, so neither
    # ever arrives with an empty chart. project: a repo's full name, for its
    # followers.
    def quiet?(project = nil)
      week = Progress::TallyService.new(user: user, range: "week", repos: Array(project))
      week.call
      return true unless absorb_errors(week)

      totals = week.totals
      totals.commits + totals.shipped + totals.published < WORTH_SENDING
    end

    def mail_builder
      return unless user.weekly_email? && user.email.present?
      return unless claim(User.where(id: user.id), :weekly_email_sent_at)

      WeeklyMailer.week_ready(user).deliver_later
      @builder_mailed = true
    end

    # A reader who follows the whole page already gets every project in it.
    def mail_subscribers
      confirmed = user.subscriptions.confirmed
      confirmed.whole_page.find_each { |subscription| mail_digest(subscription) }

      everything = confirmed.whole_page.pluck(:email).to_set
      confirmed.projects.includes(:github_repo).group_by(&:github_repo).each do |repo, followers|
        next if quiet?(repo.full_name)

        followers.each { |subscription| mail_digest(subscription) unless everything.include?(subscription.email) }
      end
    end

    def mail_digest(subscription)
      return unless claim(Subscription.where(id: subscription.id), :digest_sent_at)

      WeeklyMailer.digest(subscription).deliver_later
      @digests_sent += 1
    end

    # Marks the row sent, unless it was sent this week, in one statement: a
    # retried job or a second run in the same week mails nobody twice.
    def claim(scope, column)
      unsent = scope.where(column => nil).or(scope.where(column => ...RESEND_AFTER.ago))
      unsent.update_all(column => Time.current) == 1
    end
  end
end
