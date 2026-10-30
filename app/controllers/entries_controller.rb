class EntriesController < ApplicationController
  include EntriesSection

  before_action :require_authentication
  before_action :set_entry, only: [ :show, :edit, :update, :destroy ]

  def create
    @entry = current_user.entries.build(entry_params)
    @entry.source = :manual

    if @entry.save
      redirect_to dashboard_path, notice: "Entry posted."
    else
      redirect_to dashboard_path, alert: @entry.errors.full_messages.to_sentence
    end
  end

  # The row again, into its frame: the edit form's Cancel.
  def show
    return redirect_to(dashboard_path) unless turbo_frame_request?

    render partial: "dashboard/entry_row", locals: { entry: @entry, tab: "timeline" }
  end

  def edit
    # Rendered inside a Turbo Frame on the dashboard
  end

  # Hide, restore, pin, make private or public, one switch a click; else the
  # edit form's fields, on an entry logged by hand.
  def update
    return switch if Entries::SwitchService::SWITCHES.any? { |key| params.key?(key) }
    return render(:edit, status: :unprocessable_entity) unless @entry.manual? && @entry.update(entry_params)

    answer(notice: "Entry updated.")
  end

  def destroy
    service = Entries::DeleteService.new(entry: @entry)
    service.call ? answer(notice: "Entry deleted.") : answer(alert: service.errors.full_messages.to_sentence)
  end

  private

  def set_entry
    @entry = current_user.entries.find(params[:id])
  end

  def entry_params
    params.require(:entry).permit(:entry_type, :title, :body, :url, :occurred_at, :repo_name)
  end

  def switch
    switches = params.slice(*Entries::SwitchService::SWITCHES).permit(*Entries::SwitchService::SWITCHES)
    service = Entries::SwitchService.new(entry: @entry, user: current_user, **switches.to_h.symbolize_keys)
    service.call ? answer : answer(alert: service.errors.full_messages.to_sentence)
  end

  # With Turbo, the Entries section redraws what the click changed and
  # nothing else, so the page keeps its place; without it, the dashboard
  # comes back on the tab and filters the click came from.
  def answer(notice: nil, alert: nil)
    respond_to do |format|
      format.turbo_stream do
        @from, @alert = entries_tab_key, alert
        changed unless alert
        render "entries/changed"
      end
      format.html { redirect_to dashboard_path(**entries_back_params, anchor: "entries"), notice: notice, alert: alert }
    end
  end

  # Every tab as it is now, and whether the entry is still in the list its
  # row was clicked in.
  def changed
    @entry_tabs = entries_tabs
    @stays = !@entry.destroyed? && @entry_tabs.find { |tab| tab.key == @from }.includes?(@entry)
  end
end
