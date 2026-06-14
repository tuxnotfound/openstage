class LlmsController < ApplicationController
  # Serves /llms.txt — a structured, plain-text summary of the site for LLMs
  # and AI search engines (see https://llmstxt.org).
  def show
    @profiles = User.active.order(created_at: :desc).limit(15)
    @profile_count = User.active.count
    @posts = BlogPost.all

    render template: "llms/show", formats: [ :text ], handlers: [ :erb ],
           layout: false, content_type: "text/plain"
  end
end
