module Revenue
  # Counts a product's revenue for a project, or stops counting it, as its
  # builder switches it on the project's view. A product counts for one
  # project. The first time a project is given a product, the time is kept for
  # good: Free counts MRR for the one set up first (Slot), and giving any other
  # project a product is refused, with Pro offered.
  class CountProductService < ApplicationService
    attr_accessor :repo, :product, :counted

    validates :repo, :product, presence: true
    validates :counted, inclusion: { in: [ true, false ] }
    validate :the_builders_product, :not_counted_elsewhere, :one_project_on_free

    private

    def execute
      transaction do
        hold_builder if counted
        save_count if errors.none?
      end
    end

    # Two projects given products at once both pass the check above, and
    # Free would count both. With its builder's row locked, the later one
    # reads the slot the first took, and is refused.
    def hold_builder
      repo.user.lock!
      one_project_on_free
    end

    def save_count
      product.update(github_repo: counted ? repo : nil)
      repo.update(revenue_set_up_at: repo.revenue_set_up_at || Time.current) if counted
      absorb_errors(product) && absorb_errors(repo)
    end

    def the_builders_product
      errors.add(:base, "That product is not in your Stripe account.") if repo && product && product.revenue_account.user_id != repo.user_id
    end

    def not_counted_elsewhere
      other = product&.github_repo
      errors.add(:base, "#{product.name} counts for #{other.name}. Switch it off there first.") if counted && other && other.id != repo&.id
    end

    def one_project_on_free
      slot_project = Slot.new(repo.user).instead_of(repo) if counted && repo
      errors.add(:base, "Free counts MRR for one project, #{slot_project.name}. Go Pro to count it for every project.") if slot_project
    end
  end
end
