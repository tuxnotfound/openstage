# The builder's card of the window and projects in view on their page, inside
# the Make a card dialog, drawn with the page's chart: its theme, the entries
# left off with Swap in, and the post to go with it. Owner only: it draws the
# signed-in builder's card.
class ProgressCardsController < ApplicationController
  before_action :require_authentication

  def show
    service = Progress::ComposeService.new(user: current_user, range: params[:range], rolling: true,
                                           repos: Array(params[:repo]).map(&:to_s).compact_blank, swapped_ids: swapped_ids)
    return head(:unprocessable_entity) unless service.call

    @section = service.section
    @layout = CardLayout::Progress.new(@section, user: current_user, theme: params[:theme])
  end

  private

  # "12,8": the entries swapped in, in the order they were.
  def swapped_ids
    params[:swap].to_s.split(",").map(&:to_i).select(&:positive?).uniq
  end
end
