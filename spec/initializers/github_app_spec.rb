require "rails_helper"
require "support/env_helper"

RSpec.describe "The GitHub App initializer" do
  let(:key) { OpenSSL::PKey::RSA.new(2048) }
  let(:one_line) { key.to_pem.gsub("\n", "\\n") }

  around do |example|
    settings = Rails.configuration.x.github_app
    saved = settings.to_h
    example.run
  ensure
    settings.clear
    settings.merge!(saved)
  end

  def private_key_read_from(value)
    with_env("GITHUB_APP_PRIVATE_KEY" => value) { load Rails.root.join("config/initializers/github_app.rb") }
    OpenSSL::PKey::RSA.new(Rails.configuration.x.github_app.private_key).to_pem
  end

  it "reads the key as Kamal's env file delivers it, every backslash doubled" do
    doubled = one_line.gsub("\\n") { "\\\\n" }
    expect(doubled).to include("\\\\n")
    expect(private_key_read_from(doubled)).to eq(key.to_pem)
  end

  it "reads the one-line key as .env.kamal holds it" do
    expect(private_key_read_from(one_line)).to eq(key.to_pem)
  end

  it "reads a key pasted with its newlines, as Render kept it" do
    expect(private_key_read_from(key.to_pem)).to eq(key.to_pem)
  end
end
