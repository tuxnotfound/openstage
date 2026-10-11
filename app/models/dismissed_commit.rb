# A commit the builder deleted from their page, kept by SHA so the GitHub sync
# never imports it again. Deleted with the user by the database (on_delete).
class DismissedCommit < ApplicationRecord
  belongs_to :user

  validates :sha, presence: true
end
