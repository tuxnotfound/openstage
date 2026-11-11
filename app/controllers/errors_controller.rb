# The exceptions app's page for a path no route or record answers
# (config/application.rb). Other errors keep their static pages.
class ErrorsController < ApplicationController
  def not_found
    render_not_found
  end
end
