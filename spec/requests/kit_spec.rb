require "rails_helper"

# The revamp's components page, and the light and dark rules it is the first
# page to follow.
RSpec.describe "Kit", type: :request do
  def body_tag
    response.body[/<body[^>]*>/]
  end

  it "shows the components with the theme switch" do
    get "/_kit"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("os-panel", "os-btn", "os-pill", "os-switch", "os-chart")
    expect(response.body).to include('data-controller="theme"')
  end

  it "follows the system setting until the visitor picks" do
    get "/_kit"

    expect(body_tag).not_to include("data-theme")
  end

  it "follows the visitor's pick" do
    cookies[:theme] = "dark"

    get "/_kit"

    expect(body_tag).to include('data-theme="dark"')
  end

  it "ignores a theme it does not know" do
    cookies[:theme] = "sepia"

    get "/_kit"

    expect(body_tag).not_to include("data-theme")
  end

  # A page not yet drawn in the new look has fixed colours, so it stays light
  # whatever the visitor picked elsewhere, and offers no switch.
  it "pins a page not yet in the new look to light" do
    sign_in_as(create(:user, pro: true))
    cookies[:theme] = "dark"

    get "/analytics"

    expect(body_tag).to include('data-theme="light"')
    expect(response.body).not_to include('data-controller="theme"')
  end
end
