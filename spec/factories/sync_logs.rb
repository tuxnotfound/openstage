FactoryBot.define do
  factory :sync_log do
    association :user
    source { "github" }
    status { "success" }
    entries_added { 0 }
    ran_at { Time.current }
  end
end
