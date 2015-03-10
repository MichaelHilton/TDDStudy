class AddJsonasTs < ActiveRecord::Migration
  def change
    create_table :ast_json_trees do |t|
      t.references :session, index: true
      t.text :ast_json_tree
      t.string :filename
      t.integer :git_tag
      t.timestamps
    end
  end
end
