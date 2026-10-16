module Entries
  # Tags one of the builder's entries with a project, or marks it as having
  # none, for the progress section's project views. Any entry type, synced or
  # typed: nothing else about it changes.
  class TagService < ApplicationService
    # repo_name: the project; ignored when no_project is set.
    attr_accessor :entry, :repo_name, :no_project

    validates :entry, presence: true
    validate :project_chosen

    private

    def execute
      if no_project
        entry.update(repo_name: nil, no_project: true)
      else
        entry.update(repo_name: repo_name, no_project: false)
      end
      absorb_errors(entry)
    end

    def project_chosen
      errors.add(:repo_name, "is needed, or say it has no project") if !no_project && repo_name.to_s.strip.empty?
    end
  end
end
