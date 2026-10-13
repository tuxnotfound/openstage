# The week card editor. The builder picks what goes on the card, writes each
# day's headline in their own words and the post that goes out with it. Every
# change saves at once and redraws the preview; the PNG is drawn in the browser
# from the same SVG.
class WeekCardsController < ApplicationController
  before_action :require_authentication
  before_action :load_week_card

  def show
    service = WeekCards::ComposeService.new(week_card: @week_card)
    return head(:unprocessable_entity) unless service.call

    @card = service.card
    Event.track("card_opened", user: current_user)
    Event.track("recap_from_email", user: current_user) if params[:from] == "weekly"
  end

  def update
    @week_card.assign_attributes(week_card_params)
    return head(:unprocessable_entity) unless @week_card.save

    # The editor saves with fetch and then reloads its preview frame. The zone
    # comes back so the editor knows whether the browser's zone was kept.
    respond_to do |format|
      format.json { render json: { time_zone: @week_card.time_zone } }
      format.html { redirect_to week_card_path(@week_card) }
    end
  end

  # The card alone, for the editor's preview frame.
  def preview
    service = WeekCards::ComposeService.new(week_card: @week_card)
    return head(:unprocessable_entity) unless service.call

    render partial: "preview", locals: { card: service.card }
  end

  private

  # Always the signed-in builder's own card. A future week has nothing to show.
  def load_week_card
    week_start = params[:week] ? WeekCard.week_start_for(params[:week]) : Date.current.beginning_of_week
    return head(:not_found) unless week_start
    return redirect_to(current_week_card_path) if week_start > Date.current

    @week_card = WeekCard.find_or_initialize_by(user: current_user, week_start: week_start)
    @week_card.time_zone ||= WeekCard.last_time_zone_for(current_user)
  end

  def week_card_params
    params.require(:week_card).permit(:layout, :theme, :next_goal, :time_zone, :post_text,
                                      sections: {}, projects: {}, headlines: {})
  end
end
