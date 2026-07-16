# Regression tests for BUG-03 and BUG-07.
# See docs/bug-tickets.md for the full ticket write-ups.
#
# BUG-03: PostsController#update finds the post but never assigns the
# submitted params or calls save/update, then unconditionally redirects
# with a success flash. Edits are silently discarded.
#
# BUG-07: when a non-owning user attempts the same action, the lookup
# (`current_user.posts.find(params[:id])`) correctly fails to find the
# record, but does so via an unhandled ActiveRecord::RecordNotFound
# rather than a rescued, graceful response.

require 'rails_helper'

RSpec.describe 'Post update', type: :request do
  let(:password) { 'password123' }
  let!(:author) { User.create!(email: 'author@example.com', password: password) }
  let!(:other_user) { User.create!(email: 'other@example.com', password: password) }
  let!(:post_record) { Post.create!(title: 'Original Title', html_body: '<p>Original body</p>', author: author) }

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: password } }
  end

  describe 'BUG-03: edits should persist' do
    it 'saves the updated title and body to the database' do
      sign_in(author)

      patch post_path(post_record), params: {
        post: { title: 'Updated Title', html_body: '<p>Updated body</p>' }
      }

      post_record.reload
      expect(post_record.title).to eq('Updated Title')
      expect(post_record.html_body).to eq('<p>Updated body</p>')
    end
  end

  describe 'BUG-07: cross-user edit attempts should be handled gracefully' do
    it 'does not persist changes from a non-owning user' do
      sign_in(other_user)

      # NOTE: the app currently blocks this at the DB layer via
      # `current_user.posts.find`, which raises RecordNotFound rather
      # than returning a handled response. Authorization holds; the
      # *handling* of that case does not. If a rescue_from is added to
      # PostsController, replace this expectation with a status check
      # (e.g. `expect(response).to have_http_status(:not_found)`).
      expect {
        patch post_path(post_record), params: { post: { title: 'Hijacked Title' } }
      }.to raise_error(ActiveRecord::RecordNotFound)

      post_record.reload
      expect(post_record.title).to eq('Original Title')
    end
  end
end
