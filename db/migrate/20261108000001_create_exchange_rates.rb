class CreateExchangeRates < ActiveRecord::Migration[7.1]
  def change
    # The ECB's reference rate for a currency on a day: how much of it one euro
    # buys. The ECB publishes on working days only, and not for every currency.
    create_table :exchange_rates do |t|
      t.string :currency, null: false
      t.date :day, null: false
      t.decimal :per_euro, precision: 18, scale: 6, null: false
      t.index %i[currency day], unique: true
    end
  end
end
