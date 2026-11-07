module Projects
  # A Stripe product its builder counts for a project, or stops counting, from
  # the Revenue (MRR) row on the project's view.
  class RevenueProductsController < ApplicationController
    before_action :require_authentication

    def update
      repo = current_user.github_repos.find(params[:project_id])
      product = current_user.revenue_products.find(params[:id])
      service = Revenue::CountProductService.new(repo: repo, product: product, counted: ActiveModel::Type::Boolean.new.cast(params[:counted]))
      flash_message = service.call ? {} : { alert: service.errors.full_messages.to_sentence }

      # Back with the products open, under the row; a refusal lands at the
      # top of the page, where its alert says why.
      redirect_to edit_project_path(repo, revenue: "open", anchor: ("revenue" if flash_message.empty?)), status: :see_other, **flash_message
    end
  end
end
