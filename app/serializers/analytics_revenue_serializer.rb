# The MRR tab's own parts (Analytics::RevenueParts), in the currency the
# chart is in: its products, each a ranked row with its project's dot and
# name, its MRR on the last day read and its subscriptions; and MRR by week,
# or by month, each titled as the chart's tooltip titles one, with what it
# added or took ("–" for nothing, up saying which) and where MRR stood at
# its end. With no product counted for a project, one line says so (empty).
class AnalyticsRevenueSerializer < ApplicationSerializer
  include ActionView::Helpers::NumberHelper

  EMPTY = "No Stripe product counts for a project yet.".freeze

  # report: an Analytics::ReportService with its revenue_parts.
  def initialize(report)
    @report = report
    @parts = report.revenue_parts
  end

  def attributes
    { products: products, steps: { title: "MRR by #{@parts.unit}", rows: steps }, empty: (EMPTY if @parts.none?) }
  end

  private

  def products
    list = @parts.products
    most = list.map(&:mrr).max
    list.map do |product|
      row = product.row
      { label: product.name, count: money(product.mrr), width: most.positive? ? [ 1.5, 100.0 * product.mrr / most ].max.round(1) : 0,
        color_class: row.color_class, of: row.name, other: false,
        subscriptions: "#{number_with_delimiter(product.subscriptions)} #{'subscription'.pluralize(product.subscriptions)}" }
    end
  end

  # A change as the page writes it, whole, so one that rounds to nothing
  # reads "–" with no arrow.
  def steps
    labels = @report.totals_window.labels
    @parts.steps.map do |step|
      change = step.change.round
      { label: labels.bucket_title(step.days, @parts.unit), amount: change.zero? ? "–" : money(change.abs), up: (change.positive? unless change.zero?),
        mrr: money(step.mrr) }
    end
  end

  def money(units)
    Revenue::Money.write(units, @parts.currency)
  end
end
