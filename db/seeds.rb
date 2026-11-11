# Seeds are intentionally minimal: development data alone, each file in
# db/seeds/ a builder whose page is worth seeing in a shape production has.
return unless Rails.env.development?

Dir[Rails.root.join("db/seeds/*.rb")].sort.each { |file| load file }
