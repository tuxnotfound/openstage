# The builder's card for the period in view on their page, inside the Make a
# card dialog: the Footnotes card for Bars, the Journey card for Lines, with
# its theme, the entries left off with Swap in, and the post to go with it.
# Owner only: it draws the signed-in builder's card.
class ProgressCardsController < ApplicationController
  before_action :require_authentication

  def show
    service = Progress::ComposeService.new(user: current_user, range: params[:range], offset: params[:offset],
                                           repo: params[:repo].presence, swapped_ids: swapped_ids)
    return head(:unprocessable_entity) unless service.call

    @section = service.section
    layout = params[:chart] == "lines" ? CardLayout::Journey : CardLayout::Footnotes
    @layout = layout.new(@section, user: current_user, theme: params[:theme])
  end

  private

  # "12,8": the entries swapped in, in the order they were.
  def swapped_ids
    params[:swap].to_s.split(",").map(&:to_i).select(&:positive?).uniq
  end
end
