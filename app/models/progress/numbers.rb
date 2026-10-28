module Progress
  # The numbers a chart can draw, in the order every page lists them: where
  # each one happens (its group), whether it counts over a window (a flow,
  # like commits) or stands at a point in time (a level, like MRR), and
  # whether it is money. A project's builder picks which of its numbers its
  # visitors see (GithubRepo#hidden_numbers); Openstage's own numbers are
  # analytics' alone, and no project picks them. MRR, stars and pull requests
  # join as rows here.
  class Numbers
    # picked: a project's builder shows it or hides it.
    Number = Data.define(:key, :label, :group, :level, :money, :picked) do
      def level?
        level
      end

      def money?
        money
      end

      # Its name inside a sentence: "site visits", but "MRR".
      def word
        label.match?(/\A[A-Z]{2,}\z/) ? label : label.downcase
      end
    end

    ALL = [
      Number.new(key: "commits", label: "Commits", group: "On GitHub", level: false, money: false, picked: true),
      Number.new(key: "visits", label: "Site visits", group: "On your websites", level: false, money: false, picked: true),
      Number.new(key: "visitors", label: "Visitors", group: "On Openstage", level: false, money: false, picked: false),
      Number.new(key: "views", label: "Views", group: "On Openstage", level: false, money: false, picked: false),
      Number.new(key: "follows", label: "New followers", group: "On Openstage", level: false, money: false, picked: false),
      Number.new(key: "clicks", label: "Clicks out", group: "On Openstage", level: false, money: false, picked: false)
    ].freeze

    # The numbers a project's builder shows its visitors or hides from them.
    PICKED = ALL.select(&:picked).map(&:key).freeze

    def self.find(key)
      ALL.find { |number| number.key == key.to_s }
    end

    # The numbers some keys name, once each, in the pages' order.
    def self.in_order(keys)
      wanted = Array(keys).map(&:to_s)
      ALL.select { |number| wanted.include?(number.key) }
    end
  end
end
