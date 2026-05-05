FactoryBot.define do
  factory :profile_view do
    association :user
    viewed_at { Time.current }
    referrer { nil }
    ip_hash { Digest::SHA256.hexdigest("192.168.1.1#{Date.current}") }
    country { nil }
  end
end
