class AddHiddenNumbersToGithubRepos < ActiveRecord::Migration[7.1]
  # What a project shows its visitors, as the numbers its builder hid from
  # them: a number left out shows, so a new one starts shown. It replaces the
  # dashboard chart's own picks (dashboard_hidden, which only that chart
  # read) and the site visits switch (site_visits_shown), whose off carries
  # over as site visits hidden.
  def up
    add_column :github_repos, :hidden_numbers, :jsonb, default: [], null: false
    execute "UPDATE github_repos SET hidden_numbers = '[\"visits\"]'::jsonb WHERE site_visits_shown = false"
    remove_column :github_repos, :dashboard_hidden
    remove_column :github_repos, :site_visits_shown
  end

  def down
    add_column :github_repos, :site_visits_shown, :boolean, default: true, null: false
    add_column :github_repos, :dashboard_hidden, :jsonb, default: [], null: false
    execute "UPDATE github_repos SET site_visits_shown = false WHERE hidden_numbers ? 'visits'"
    remove_column :github_repos, :hidden_numbers
  end
end
