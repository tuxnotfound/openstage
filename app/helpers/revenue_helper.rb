module RevenueHelper
  # The Revenue (MRR) row on a project's builder view: the line under its
  # name, and the state beside it. overview: a Projects::GatherService.
  def revenue_status(repo, overview)
    if overview.revenue_account.nil? then [ "From Stripe, once you connect it on Integrations.", "Off" ]
    elsif overview.revenue_slot_project
      [ "You already count MRR on #{overview.revenue_slot_project.name}, the one project Free counts.", "Off" ]
    elsif (names = counted_products(repo, overview).map(&:name).to_sentence(last_word_connector: " and ")).empty?
      [ "No Stripe product counts for it yet.", "Off" ]
    elsif repo.user.pro? then [ "Verified with Stripe, from #{names}.", "" ]
    else [ "Verified with Stripe, from #{names}. Only you see it: Pro shows it on its page.", "Only you" ]
    end
  end

  # A project's MRR and paying subscriptions on the last day read, from the
  # products it counts: [figure, count], the figure nil before any revenue
  # is read. A project paid in several currencies lists each, the largest
  # first.
  def revenue_now(repo, overview)
    days = counted_products(repo, overview).flat_map { |product| overview.revenue_days.fetch(product.id, []) }
    [ money_figure(days), days.sum(&:subscriptions) ]
  end

  # What a product's row under the picker says about it, beside its name:
  # its own MRR and subscriptions, and where it stands.
  def revenue_product_note(repo, product, overview)
    days = overview.revenue_days.fetch(product.id, [])
    figure = "#{money_figure(days)} MRR · #{pluralize(days.sum(&:subscriptions), 'subscription')}" if days.any?
    [ figure, product_place(repo, product) ].compact.join(" · ").presence
  end

  private

  def counted_products(repo, overview)
    overview.revenue_products.select { |product| product.github_repo_id == repo.id }
  end

  def product_place(repo, product)
    if product.github_repo && product.github_repo_id != repo.id then "Counts for #{product.github_repo.name}"
    elsif !product.active? then "Archived in Stripe"
    end
  end

  def money_figure(days)
    totals = days.group_by(&:currency).transform_values { |rows| rows.sum(&:mrr) }.sort_by { |_, amount| -amount }
    totals.map { |currency, amount| Revenue::Money.format(amount, currency) }.join(" + ").presence
  end
end
