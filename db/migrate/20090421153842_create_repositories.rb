class CreateRepositories < ActiveRecord::Migration
  def self.up
    create_table :repositories do |t|
      t.string :url
      t.string :username
      t.string :password
      t.timestamps
    end
  end

  def self.down
    drop_table :repositories
  end
end
