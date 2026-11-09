module RevenueHelper
  # The Revenue (MRR) row on a project's builder view: the line under its
  # name, and the state beside it. overview: a Projects::GatherService.
  def revenue_status(repo, overview)
    if overview.revenue_account.nil? then [ "From Stripe, once you connect it on Integrations.", "Off" ]
    elsif overview.revenue_account.refused_at then [ "Stripe refuses your key, so its figures are off your pages. Connect a new one on Integrations.", "Off" ]
    elsif overview.revenue_account.stale? then [ "Openstage has not read Stripe since #{overview.revenue_account.last_read.strftime('%b %-d')}, so its figures are off your pages. It tries again every night.", "Off" ]
    elsif overview.revenue_slot_project
      [ "You already count MRR on #{overview.revenue_slot_project.name}, the one project Free counts.", "Off" ]
    elsif (names = counted_products(repo, overview).map(&:name).to_sentence(last_word_connector: " and ")).empty?
      [ "No Stripe product counts for it yet.", "Off" ]
    elsif repo.user.pro? then [ "Verified with Stripe, from #{names}.#{left_out_note(overview)}", revenue_state(repo, "mrr") ]
    else [ "Verified with Stripe, from #{names}.#{left_out_note(overview)} Only you see it: Pro shows it on its page.", "Only you" ]
    end
  end

  # Whether a project's products can be picked here: Stripe connected and
  # reading, and no other project holding Free's slot.
  def revenue_products_open?(overview)
    overview.revenue_account.present? && overview.revenue_account.refused_at.nil? && overview.revenue_slot_project.nil?
  end

  # A number's state on a project's row: Pro shows it, or hides it, by its
  # switch; on Free only its builder sees it.
  def revenue_state(repo, number)
    return "Only you" unless repo.user.pro?

    repo.picks?(number) ? "Shown" : "Hidden"
  end

  # A project's MRR and paying customers on the last day read, in one
  # currency (Revenue::Levels): [figure, count], the figure nil before any
  # revenue is read. With nothing that day it stands at nothing, as on its page.
  def revenue_now(repo, overview)
    levels = overview.revenue_levels
    return [ nil, 0 ] unless levels&.currency

    [ Revenue::Money.write(levels.mrr(repo.id).values.sum, levels.currency), levels.customers(repo.id).values.sum ]
  end

  # What a project's page says of its revenue, under its description, of what
  # its builder shows: [the first figure, the words after it], nil with
  # neither. chart: the page's Progress::ChartService, of its one project.
  def revenue_on_page(chart)
    row = chart.rows.first
    parts = Progress::Numbers::REVENUE.select { |key| row&.shows?(key) }.map { |key| revenue_part(chart.counts, Progress::Numbers.find(key), row) }
    return if parts.empty?

    [ parts.first.first, [ parts.first.last, *parts.drop(1).map { |amount, word| "#{amount} #{word}" } ].join(" · ") ]
  end

  # What a product's row under the picker says about it, beside its name:
  # its own MRR and subscriptions, and where it stands.
  def revenue_product_note(repo, product, overview)
    days = overview.revenue_days.fetch(product.id, [])
    figure = "#{money_figure(days)} MRR · #{pluralize(days.sum(&:subscriptions), 'subscription')}" if days.any?
    [ figure, product_place(repo, product) ].compact.join(" · ").presence
  end

  private

  # [its value, its name after that value]; a project's value today.
  def revenue_part(counts, number, row)
    amount = counts.written(number, counts.sum(number.key, row.key))
    [ amount, number.word_after(amount) ]
  end

  # Said of a currency Revenue::Levels left out of the figure.
  def left_out_note(overview)
    left_out = overview.revenue_levels&.left_out
    return if left_out.blank?

    " #{left_out.map(&:upcase).to_sentence(last_word_connector: ' and ')} #{left_out.one? ? 'has' : 'have'} no ECB rate, so #{left_out.one? ? 'it is' : 'they are'} left out."
  end

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
