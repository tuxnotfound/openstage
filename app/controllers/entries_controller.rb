class EntriesController < ApplicationController
  before_action :require_authentication
  before_action :set_entry, only: [ :edit, :update, :destroy ]

  def create
    @entry = current_user.entries.build(entry_params)
    @entry.source = :manual

    if @entry.save
      redirect_to dashboard_path, notice: "Entry posted."
    else
      redirect_to dashboard_path, alert: @entry.errors.full_messages.to_sentence
    end
  end

  def edit
    # Rendered inside a Turbo Frame on the dashboard
  end

  def update
    if params.key?(:hidden)
      @entry.update!(hidden: ActiveModel::Type::Boolean.new.cast(params[:hidden]))
      redirect_to dashboard_path
    elsif params.key?(:pinned)
      @entry.update!(pinned: ActiveModel::Type::Boolean.new.cast(params[:pinned]))
      redirect_to dashboard_path
    else
      if @entry.manual? && @entry.update(entry_params)
        redirect_to dashboard_path, notice: "Entry updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    @entry.destroy
    redirect_to dashboard_path, notice: "Entry deleted."
  end

  private

  def set_entry
    @entry = current_user.entries.find(params[:id])
  end

  def entry_params
    params.require(:entry).permit(:entry_type, :title, :body, :url, :occurred_at)
  end
end
