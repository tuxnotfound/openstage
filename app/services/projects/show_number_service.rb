module Projects
  # A number a project shows its visitors, or hides from them, as its builder
  # switches it in the dashboard's table or on the project's own view. A
  # hidden number keeps counting, and its builder still sees it.
  class ShowNumberService < ApplicationService
    attr_accessor :repo, :number, :shown

    validates :repo, presence: true
    validates :number, inclusion: { in: Progress::Numbers::PICKABLE, message: "is not one a project shows" }
    validates :shown, inclusion: { in: [ true, false ] }

    private

    def execute
      hidden = shown ? repo.hidden_numbers - [ number ] : repo.hidden_numbers | [ number ]
      repo.update(hidden_numbers: hidden)
      absorb_errors(repo)
    end
  end
end
