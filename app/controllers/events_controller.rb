# What happens in the browser on the cards (a download, a copied post, a
# compose box opened) is reported here. Only the names a browser is allowed to
# claim are accepted, each with its own short list of details.
class EventsController < ApplicationController
  before_action :require_authentication

  def create
    name = params[:name].to_s
    return head(:unprocessable_entity) unless Event::CLIENT_NAMES.include?(name)

    detail = Event::DETAILS.fetch(name, []).include?(params[:detail].to_s) ? params[:detail].to_s : ""
    Event.track(name, user: current_user, detail: detail)
    head :no_content
  end
end
