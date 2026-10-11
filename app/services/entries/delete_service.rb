module Entries
  # Deletes an entry from the builder's page. A deleted commit is remembered by
  # its SHA, so re-syncing its repo from scratch (a renamed default branch, a
  # private repo picked again) never brings it back.
  class DeleteService < ApplicationService
    attr_accessor :entry

    validates :entry, presence: true

    private

    def execute
      transaction do
        dismiss_commit if entry.github? && entry.external_id.present?
        entry.destroy!
      end
    end

    def dismiss_commit
      DismissedCommit.create_or_find_by!(user_id: entry.user_id, sha: entry.external_id)
    end
  end
end
