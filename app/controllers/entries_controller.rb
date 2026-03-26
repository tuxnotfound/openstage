class EntriesController < ApplicationController
  before_action :require_authentication

  def create
    @entry = current_user.entries.build(entry_params)
    @entry.source = :manual

    if @entry.save
      redirect_to dashboard_path, notice: "Entry posted."
    else
      redirect_to dashboard_path, alert: @entry.errors.full_messages.to_sentence
    end
  end

  def update
    entry = current_user.entries.find(params[:id])
    entry.update!(hidden: params[:hidden])
    redirect_to dashboard_path
  end

  def destroy
    entry = current_user.entries.find(params[:id])
    entry.destroy
    redirect_to dashboard_path, notice: "Entry deleted."
  end

  private

  def entry_params
    params.require(:entry).permit(:entry_type, :title, :body, :url, :occurred_at)
  end
end
