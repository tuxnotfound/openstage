class HomeController < ApplicationController
  include LandingPage

  def index
    load_landing
  end
end
