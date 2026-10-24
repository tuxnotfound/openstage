require "rails_helper"
require "open3"

# The charts' code in the browser (app/javascript/charts): it type-checks and
# its own tests pass, so one rspec run covers it too. It needs Node, as the
# bundle does.
RSpec.describe "The charts' browser code" do
  def run(*command)
    Open3.capture2e(*command, chdir: Rails.root.to_s)
  end

  it "type-checks" do
    output, status = run("npx", "tsc", "--noEmit")
    expect(status).to be_success, output
  end

  it "passes its tests" do
    output, status = run("npx", "vitest", "run")
    expect(status).to be_success, output
  end
end
