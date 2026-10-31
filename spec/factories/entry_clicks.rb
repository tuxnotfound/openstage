FactoryBot.define do
  factory :entry_click do
    association :user
    association :entry
    clicked_at { Time.current }
  end
end
