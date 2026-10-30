require "rails_helper"

# A builder's public page is their stage: "your page" was too general once
# every project had a page of its own (Pedro, 2026-10-30). Project pages
# stay pages.
RSpec.describe "The builder's stage, by name", type: :request do
  let(:user) { create(:user, username: "builder", pro: true) }
  let!(:repo) { create(:github_repo, user: user, full_name: "builder/app", name: "app") }

  before { create(:entry, user: user, repo_name: "builder/app") }

  def expect_stage_only(*phrases)
    expect(response.body).to include(*phrases)
    expect(response.body).not_to match(/\b(your|my|their) page\b/i)
  end

  it "names it on every page the builder manages it from" do
    sign_in_as(user)

    get "/dashboard"
    expect_stage_only("Your stage ", "Put your stage in a README", "Shows on your stage and on its project's page.",
                      "what visitors see on your stage and your project pages", ">Your stage</th>", "Show app on your stage")

    get "/settings"
    expect_stage_only(">Your stage</h2>", "Show on your stage", "with a link to your stage.", "shows on your stage, marked with its branch",
                      "from the box on your stage or on a project's page.")

    get "/projects/#{repo.id}/edit"
    expect_stage_only("On your stage", "Its page is public, and it shows on your stage.", "Show app on your stage")

    get "/analytics", params: { range: "30d" }
    expect_stage_only("Show only Your stage", "On Openstage, your stage and your project pages")

    get "/embed/builder/preview"
    expect_stage_only("links back to your stage.")
  end

  it "names it to a builder who hid a project and opens its page" do
    repo.update!(included: false)
    sign_in_as(user)

    get "/builder/app"
    expect_stage_only("so visitors who open it land on your stage.")
  end

  it "names it on the landing, pricing and privacy pages, and to visitors of a stage" do
    get "/"
    expect_stage_only("Share your stage wherever you like", "Your stage, a page for each project", "Your stage charts each project",
                      "on your stage and on the project")

    get "/pricing"
    expect_stage_only("free forever: your stage, a page for each project", "Your proof-of-work stage, synced from GitHub",
                      "A subscribe box on your stage", "every address that confirmed on your stage")

    get "/privacy"
    expect(response.body).to include("A visit to a builder's stage or a project's page")

    get "/blog/rebuilt-on-itself"
    expect_stage_only("For 82 days my stage on Openstage", "Your GitHub commits become your proof-of-work stage.")

    user.update!(pro: false)
    get "/builder"
    expect(response.body).to include("Get your own proof-of-work stage", "'s proof-of-work stage\"")
  end

  it "names it when a builder claims a username or comes back" do
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(uid: "stage_uid", info: { nickname: "newcomer", name: "New Comer" },
                                                                credentials: { token: "gho_stage" })
    allow(GithubSyncJob).to receive(:perform_later)
    get "/auth/github/callback"
    post claim_username_path, params: { username: "newcomer" }

    expect(flash[:notice]).to eq("Welcome to Openstage, New Comer! This is your stage.")
    expect(SessionsController::RESTORED).to eq("Welcome back. Your account is restored and your stage is online again.")
  end

  it "names it in the emails" do
    week = WeeklyMailer.week_ready(user.tap { |builder| builder.update!(email: "b@example.com") })
    subscription = user.subscriptions.create!(email: "reader@example.com", confirmed_at: Time.current)

    expect(week.text_part.body.to_s).to include("See your stage:")
    expect(WeeklyMailer.digest(subscription).text_part.body.to_s).to include("See the week on #{user.display_name}'s stage")
  end

  it "says a project followed from another builder's stage is not on theirs" do
    other = create(:github_repo, full_name: "someone/else", name: "else")
    subscription = user.subscriptions.build(email: "reader@example.com", github_repo: other)

    expect(subscription).not_to be_valid
    expect(subscription.errors.full_messages).to include("Github repo is not on this builder's stage")
  end
end
