module Revenue
  # Every item of a Stripe list, page after page. read_page reads one page
  # (StripeGateway) from the params it is given.
  module Paging
    PAGE = 100

    private

    def each_item(read_page)
      params = { limit: PAGE }
      loop do
        page = read_page.call(params)
        page[:data].each { |item| yield item }
        break unless page[:has_more] && page[:data].any?

        params = params.merge(starting_after: page[:data].last[:id])
      end
    end

    def all_items(read_page)
      items = []
      each_item(read_page) { |item| items << item }
      items
    end
  end
end
