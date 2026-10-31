FactoryBot.define do
  factory :badge_impression do
    association :user
    kind { "badge" }
    viewed_at { Time.current }
    referrer { nil }
  end
end
