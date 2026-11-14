# Fake R2 settings: WebMock answers every call made with them.
R2_TEST_SETTINGS = { "R2_ENDPOINT" => "https://r2.test", "R2_BUCKET" => "backups",
                     "R2_ACCESS_KEY_ID" => "id", "R2_SECRET_ACCESS_KEY" => "secret" }.freeze

# Sets ENV for one example and puts the old values back, even when the example fails.
module EnvHelper
  def with_env(values)
    previous = values.keys.index_with { ENV[it] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end

RSpec.configure { |config| config.include EnvHelper }
