FactoryBot.define do
  factory :entry do
    association :user
    entry_type { "shipped" }
    source { "github" }
    sequence(:title) { |n| "Commit message #{n}" }
    occurred_at { Time.current }
    hidden { false }
    external_id { nil }
    repo_name { nil }
  end
end
