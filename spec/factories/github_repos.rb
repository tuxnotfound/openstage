FactoryBot.define do
  factory :github_repo do
    association :user
    sequence(:github_repo_id) { |n| 100_000 + n }
    sequence(:name) { |n| "repo#{n}" }
    sequence(:full_name) { |n| "user/repo#{n}" }
    description { nil }
    url { "https://github.com/user/repo" }
    included { true }
    default_branch { "main" }
    last_synced_at { nil }
  end
end
