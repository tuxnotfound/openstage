module RevenueHelper
  # The Revenue (MRR) row on a project's builder view: the line under its
  # name, and the state beside it. overview: a Projects::GatherService.
  def revenue_status(repo, overview)
    if overview.revenue_account.nil? then [ "From Stripe, once you connect it on Integrations.", "Off" ]
    elsif overview.revenue_slot_project
      [ "You already count MRR on #{overview.revenue_slot_project.name}, the one project Free counts.", "Off" ]
    elsif (names = counted_product_names(repo, overview)).empty? then [ "No Stripe product counts for it yet.", "Off" ]
    elsif repo.user.pro? then [ "Verified with Stripe, from #{names}.", "" ]
    else [ "Verified with Stripe, from #{names}. Only you see it: Pro shows it on its page.", "Only you" ]
    end
  end

  # What a product's row under the picker says about it, beside its name.
  def revenue_product_note(repo, product)
    if product.github_repo && product.github_repo_id != repo.id then "Counts for #{product.github_repo.name}"
    elsif !product.active? then "Archived in Stripe"
    end
  end

  private

  def counted_product_names(repo, overview)
    overview.revenue_products.select { |product| product.github_repo_id == repo.id }.map(&:name).to_sentence(last_word_connector: " and ")
  end
end
