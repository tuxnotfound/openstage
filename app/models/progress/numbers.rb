module Progress
  # The numbers the pages count, in the order every page lists them: where
  # each one happens (its group), whether it counts over a window (a flow,
  # like commits) or stands at a point in time (a level, like MRR), whether
  # it is money, and whether a chart draws it or only shows it beside
  # another number in its tooltip. A project's builder picks which of its
  # numbers its visitors see (GithubRepo#hidden_numbers); Openstage's own
  # numbers are analytics' alone, and no project picks them. MRR, stars and
  # pull requests join as rows here.
  class Numbers
    # one: its name inside a sentence for one of it ("site visit");
    # pickable: a project's builder shows it or hides it; beside: for a
    # number that draws no line of its own, the key of the number whose
    # tooltip shows it: site visitors, whose line would only retrace site
    # visits', sit beside them. nil for every number with lines.
    Number = Data.define(:key, :label, :one, :group, :level, :money, :pickable, :beside) do
      def initialize(beside: nil, **fields)
        super
      end

      def level?
        level
      end

      def money?
        money
      end

      # Whether a chart draws it in lines of its own, so a toggle offers it.
      def drawable?
        beside.nil?
      end

      # Its name inside a sentence: "site visits", but "MRR".
      def word
        label.match?(/\A[A-Z]{2,}\z/) ? label : label.downcase
      end

      # Its name after an amount as the pages write it: "1 site visit", "3 site visits".
      def word_after(amount)
        amount == "1" ? one : word
      end
    end

    ALL = [
      Number.new(key: "commits", label: "Commits", one: "commit", group: "On GitHub", level: false, money: false, pickable: true),
      Number.new(key: "visits", label: "Site visits", one: "site visit", group: "On your websites", level: false, money: false, pickable: true),
      Number.new(key: "site_visitors", label: "Site visitors", one: "site visitor", group: "On your websites", level: false, money: false, pickable: true, beside: "visits"),
      Number.new(key: "visitors", label: "Visitors", one: "visitor", group: "On Openstage", level: false, money: false, pickable: false),
      Number.new(key: "views", label: "Views", one: "view", group: "On Openstage", level: false, money: false, pickable: false),
      Number.new(key: "follows", label: "New followers", one: "new follower", group: "On Openstage", level: false, money: false, pickable: false),
      Number.new(key: "clicks", label: "Clicks out", one: "click out", group: "On Openstage", level: false, money: false, pickable: false)
    ].freeze

    # The numbers a project's builder shows its visitors or hides from them.
    PICKABLE = ALL.select(&:pickable).map(&:key).freeze
    # The numbers Openstage's script counts on a project's website: visitors
    # see them only while it counts there (GithubRepo#public_number?).
    SITE = %w[visits site_visitors].freeze

    def self.find(key)
      ALL.find { |number| number.key == key.to_s }
    end

    # The numbers some keys name, once each, in the pages' order.
    def self.in_order(keys)
      wanted = Array(keys).map(&:to_s)
      ALL.select { |number| wanted.include?(number.key) }
    end

    # The numbers a tooltip shows beside a number's own value, in the pages'
    # order (Number#beside).
    def self.beside(number)
      ALL.select { |other| other.beside == number.key }
    end
  end
end
