# A product's MRR and paying subscriptions on a day, in one currency, as the
# last read of its Stripe account counted them (Revenue::ReadService).
class RevenueDay < ApplicationRecord
  belongs_to :revenue_product
end
