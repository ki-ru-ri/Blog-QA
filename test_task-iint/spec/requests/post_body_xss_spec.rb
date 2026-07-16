# Regression test for BUG-02: Stored XSS via unsanitized post body
# See docs/bug-tickets.md for the full ticket write-up.
#
# app/views/posts/_post.html.erb renders `raw post.html_body`, which
# disables Rails' automatic HTML escaping. Since post bodies are plain
# user-submitted text with no sanitizer or rich-text pipeline in front
# of them, any registered user can store a script payload that executes
# in every visitor's browser who views that post or the home feed.

require 'rails_helper'

RSpec.describe 'Post body rendering', type: :request do
  let(:author) { User.create!(email: 'author@example.com', password: 'password123') }
  let(:xss_payload) { "<script>alert('xss')</script>" }

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: 'password123' } }
  end

  it 'does not render a <script> tag verbatim/unescaped on the public feed page' do
    Post.create!(title: 'XSS Feed Test', html_body: xss_payload, author: author)

    get root_path # public, no auth required

    expect(response.body).not_to include(xss_payload)
  end

  it 'does not render a <script> tag verbatim/unescaped on the individual post page' do
    # /posts/:id requires authentication (only the feed is public),
    # so this must sign in first to actually reach the post content.
    sign_in(author)
    malicious_post = Post.create!(title: 'XSS Show Test', html_body: xss_payload, author: author)

    get post_path(malicious_post)

    expect(response.body).not_to include(xss_payload)
  end
end
