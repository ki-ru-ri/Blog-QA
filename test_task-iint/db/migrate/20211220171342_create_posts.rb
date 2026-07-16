class CreatePosts < ActiveRecord::Migration[6.1]
  def change
    create_table :posts do |t|
      t.text :title, null: false
      t.text :html_body, null: false
      t.references :author, null: false, foreign_key: {to_table: :users}, index: true

      t.timestamps
    end
  end
end
