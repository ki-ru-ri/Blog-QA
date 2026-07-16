class Post < ApplicationRecord
  belongs_to :author, class_name: 'User'

  validates :title, presence: true
  validates :html_body, presence: true, on: :create
  validates :title, length: {minimum: 5, maximum: 100}
end
