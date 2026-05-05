class HomeController < ApplicationController
  def index
    @type_filter = params[:type].presence_in(Entry.entry_types.keys)

    base = Entry.publicly_visible
                .joins(:user)
                .merge(User.active)
                .includes(:user)
                .chronological

    base = base.where(entry_type: @type_filter) if @type_filter.present?
    @recent_entries = base.page(params[:page]).per(20)
  end
end
