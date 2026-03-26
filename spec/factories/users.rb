FactoryBot.define do
  factory :user do
    sequence(:github_uid) { |n| "gh#{10000 + n}" }
    sequence(:github_username) { |n| "githubuser#{n}" }
    sequence(:username) { |n| "user#{n}" }
    github_access_token { "gho_test_token" }
    display_name { Faker::Name.name }
    bio { nil }
    avatar_url { "https://avatars.githubusercontent.com/u/1" }
    website_url { nil }
    building_since { nil }
    username_changed_at { nil }
  end
end
