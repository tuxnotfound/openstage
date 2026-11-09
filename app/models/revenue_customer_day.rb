# How many customers paid for exactly these products (product_ids, RevenueProduct
# ids) on a day, as the last read of a Stripe account counted them
# (Revenue::ReadService). Revenue::Book makes a project's paying customers of them.
class RevenueCustomerDay < ApplicationRecord
  belongs_to :revenue_account
end
