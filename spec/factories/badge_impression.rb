FactoryBot.define do
  factory :badge_impression do
    association :user
    kind { "badge" }
    viewed_at { Time.current }
    referrer { nil }
    ip_hash { Digest::SHA256.hexdigest("192.168.1.1#{Date.current}") }
  end
end
