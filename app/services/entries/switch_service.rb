module Entries
  # Flips one of an entry's switches from the dashboard: hidden (off every
  # list, still counted), pinned (Pro, a few at most) or private (Pro). One
  # switch a click, given as the form posts it: "true" or "false", or for
  # visibility "private" or "public".
  class SwitchService < ApplicationService
    SWITCHES = %i[hidden pinned visibility].freeze

    attr_accessor :entry, :user, :hidden, :pinned, :visibility

    validates :entry, :user, presence: true
    validate :one_switch
    validate :pin_allowed, if: :pinning?
    validate :private_allowed, if: -> { visibility == "private" }

    private

    def execute
      entry.update!(switched)
    end

    def switched
      return { hidden: cast(hidden) } unless hidden.nil?
      return { pinned: pinning? } unless pinned.nil?

      { visibility: visibility == "private" ? :private_entry : :public_entry }
    end

    def one_switch
      errors.add(:base, "Pick one switch to flip.") unless [ hidden, pinned, visibility ].compact.one?
    end

    def pinning?
      cast(pinned)
    end

    def pin_allowed
      return errors.add(:base, "Pinning entries is a Pro feature.") unless user.pro?

      errors.add(:base, "You can pin up to 3 entries.") unless user.can_pin?
    end

    def private_allowed
      errors.add(:base, "Private entries are a Pro feature.") unless user.can_set_private?
    end

    def cast(value)
      ActiveModel::Type::Boolean.new.cast(value) || false
    end
  end
end
