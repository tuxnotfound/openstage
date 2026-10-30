FactoryBot.define do
  factory :site_visit_count do
    association :github_repo
    kind { "page" }
    day { Date.current }
    value { "/" }
    count { 1 }
  end
end
