module Projects
  # A project its builder pins to their stage, or unpins, from the
  # dashboard's table. The projects with a colour are the pinned ones
  # (Progress::Projects): until the builder pins or unpins one, the busiest,
  # as many as the palette has colours. The first change pins those as they
  # stand, so unpinning one leaves the others where they are. A project
  # joins only while a colour is free: one more is refused, never swapped
  # for another, and only a project the stage shows takes one. Unpinning
  # the last pin goes back to the busiest.
  class PinService < ApplicationService
    attr_accessor :repo, :pinned

    validates :repo, presence: true
    validates :pinned, inclusion: { in: [ true, false ] }
    validate :on_the_stage, if: -> { repo && pinned }
    validate :room_on_the_palette, if: -> { repo&.included? && pinned }

    private

    def execute
      keep = pinned ? colored | [ repo.full_name ] : colored - [ repo.full_name ]
      transaction do
        repos.where(pinned: true).where.not(full_name: keep).update_all(pinned: false, updated_at: Time.current)
        repos.where(pinned: false, full_name: keep).update_all(pinned: true, updated_at: Time.current)
      end
    end

    # The repos that wear a colour on the stage now, as visitors see it.
    def colored
      @colored ||= Progress::Projects.new(repo.user.entries.counted_on_page, pinned: repos.pinned_names).all
                                     .select { |project| ProgressChart::Palette.colored?(project.rank) }.map(&:repo)
    end

    def repos
      repo.user.github_repos
    end

    def on_the_stage
      errors.add(:base, "Show #{repo.name} on your stage before you pin it.") unless repo.included?
    end

    def room_on_the_palette
      return if colored.include?(repo.full_name) || colored.size < ProgressChart::Palette::SIZE

      errors.add(:base, "You can pin #{ProgressChart::Palette::SIZE} projects at a time. Unpin one first.")
    end
  end
end
