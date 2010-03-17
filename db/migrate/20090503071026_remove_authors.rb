class RemoveAuthors < ActiveRecord::Migration
  def self.up
    add_column :checkins, :login, :string
    remove_column :checkins, :author_id
    drop_table :authors
  end

  def self.down
    remove_column :checkins, :login
    create_table :authors
    add_column :checkins, :author_id
  end
end
