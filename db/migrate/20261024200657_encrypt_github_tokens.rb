# Encrypts the GitHub tokens stored before User#github_access_token was
# encrypted. Its own User, so later changes to the model cannot break it.
class EncryptGithubTokens < ActiveRecord::Migration[7.1]
  class User < ActiveRecord::Base
    self.table_name = "users"
    encrypts :github_access_token
  end

  def up
    User.where.not(github_access_token: nil).find_each(&:encrypt)
  end

  def down
    User.where.not(github_access_token: nil).find_each(&:decrypt)
  end
end
