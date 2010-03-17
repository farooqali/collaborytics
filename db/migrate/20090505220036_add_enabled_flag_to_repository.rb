class AddEnabledFlagToRepository < ActiveRecord::Migration
  def self.up
    add_column :repositories, :enabled, :boolean
  end

  def self.down
    remove_column :repositories, :enabled
  end
end
