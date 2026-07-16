# Regression test for BUG-01: SQL Injection in post search
# See docs/bug-tickets.md for the full ticket write-up.
#
# app/controllers/posts_controller.rb builds the search query by
# interpolating user input directly into an ILIKE clause instead of
# using parameter binding, e.g.:
#
#   @posts = @posts.where("title ILIKE '%#{q}' OR html_body ILIKE '%#{q}%'")
#
# This lets a crafted search term alter the query's logic.

require 'rails_helper'

RSpec.describe 'Post search', type: :request do
  let(:author) { User.create!(email: 'author@example.com', password: 'password123') }

  before do
    Post.create!(title: 'Ruby on Rails Tips', html_body: '<p>Body content</p>', author: author)
    Post.create!(title: 'Completely Unrelated Post', html_body: 'nothing to do with the payload', author: author)
  end

  it 'does not raise a database error on a malicious search payload' do
    malicious_payload = "' OR '1'='1"

    expect {
      get root_path, params: { search: { q: malicious_payload } }
    }.not_to raise_error

    expect(response).to have_http_status(:success)
  end

  it 'does not return unrelated records for a boolean-injection payload' do
    # A vulnerable interpolated query like `... OR '1'='1` returns every
    # post regardless of the search term. A safely parameterized query
    # should return zero matches for this nonsense term.
    get root_path, params: { search: { q: "nonexistent-term' OR '1'='1" } }

    expect(response.body).not_to include('Completely Unrelated Post')
  end
end
