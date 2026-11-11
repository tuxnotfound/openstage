module Projects
  # A project its builder pins to their stage, or unpins, from the
  # dashboard's table. Once they pin any, the pinned ones alone wear a colour
  # there, with a card and a line (Progress::Projects), so they pin as many
  # as the palette has colours at most, and only a project their stage shows.
  # A pin counts while its repo has work on Openstage (GithubRepo.with_entries),
  # as the dashboard's table counts it: one with none is on neither page.
  class PinService < ApplicationService
    attr_accessor :repo, :pinned

    validates :repo, presence: true
    validates :pinned, inclusion: { in: [ true, false ] }
    validate :on_the_stage, :room_on_the_palette, if: -> { repo && pinned }

    private

    def execute
      repo.update(pinned: pinned)
      absorb_errors(repo)
    end

    def on_the_stage
      errors.add(:base, "Show #{repo.name} on your stage before you pin it.") unless repo.included?
    end

    def room_on_the_palette
      return if repo.pinned? || repo.user.github_repos.where(pinned: true).with_entries.count < ProgressChart::Palette::SIZE

      errors.add(:base, "#{ProgressChart::Palette::SIZE} projects are pinned, one per colour. Unpin one to pin #{repo.name}.")
    end
  end
end
