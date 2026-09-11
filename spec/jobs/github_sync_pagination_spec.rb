require "rails_helper"

# The previous implementation followed Sawyer rel links and re-read
# client.last_response afterwards, which never advanced, so any result with more
# than one page looped forever. These specs pin termination.
RSpec.describe GithubSyncJob, "pagination", type: :job do
  subject(:job) { described_class.new }

  let(:per_page) { GithubSyncJob::PER_PAGE }

  def full_page = Array.new(per_page) { |i| "item-#{i}" }

  it "stops on the first partial page" do
    pages = { 1 => full_page, 2 => [ "last" ] }
    seen = []

    job.send(:each_page, ->(page) { pages.fetch(page, []) }) { |page| seen << page }

    expect(seen.size).to eq(2)
    expect(seen.last).to eq([ "last" ])
  end

  it "stops on an empty page" do
    pages = { 1 => full_page, 2 => [] }
    seen = []

    job.send(:each_page, ->(page) { pages.fetch(page, []) }) { |page| seen << page }
    expect(seen.size).to eq(1)
  end

  it "does not call the fetcher again after a short first page" do
    calls = 0
    fetch = lambda do |_page|
      calls += 1
      [ "only" ]
    end

    job.send(:each_page, fetch) { |_page| nil }
    expect(calls).to eq(1)
  end

  it "terminates on an endless feed instead of looping forever" do
    calls = 0
    endless = lambda do |_page|
      calls += 1
      full_page
    end

    job.send(:each_page, endless) { |_page| nil }

    expect(calls).to eq(GithubSyncJob::MAX_PAGES)
  end

  it "asks for each page by number" do
    requested = []
    pages = { 1 => full_page, 2 => full_page, 3 => [ "end" ] }

    job.send(:each_page, ->(page) { requested << page; pages.fetch(page, []) }) { |_page| nil }

    expect(requested).to eq([ 1, 2, 3 ])
  end
end
