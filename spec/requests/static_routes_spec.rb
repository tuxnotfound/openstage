require "rails_helper"

RSpec.describe "Static-like routes", type: :request do
  it "redirects /favicon.png to /favicon.ico" do
    get "/favicon.png"

    expect(response).to have_http_status(:moved_permanently)
    expect(response.headers["Location"]).to end_with("/favicon.ico")
  end

  it "returns 404 for wp-admin scanner requests" do
    get "/wp-admin/install.php", params: { step: 1 }

    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for xmlrpc scanner requests" do
    post "/xmlrpc.php"

    expect(response).to have_http_status(:not_found)
  end
end
