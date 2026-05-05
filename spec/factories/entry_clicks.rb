FactoryBot.define do
  factory :entry_click do
    association :user
    association :entry
    ip_hash { Digest::SHA256.hexdigest("192.168.1.1#{Date.current}") }
    clicked_at { Time.current }
  end
end
