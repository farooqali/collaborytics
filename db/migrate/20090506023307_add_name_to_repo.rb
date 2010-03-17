class AddNameToRepo < ActiveRecord::Migration
  def self.up
    add_column :repositories, :name, :string
  end

  def self.down
    remove_column :repositories, :name
  end
end
