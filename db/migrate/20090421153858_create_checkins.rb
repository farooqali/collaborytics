class CreateCheckins < ActiveRecord::Migration
  def self.up
    create_table :checkins do |t|
      t.string :revision
      t.timestamp :checked_in_at
      t.integer :files_added
      t.integer :files_deleted
      t.integer :files_modified
      t.integer :files_moved
      t.integer :lines_added
      t.integer :lines_deleted
      t.integer :lines_removed
      t.text :affected_paths
      t.text :svn_log
      t.references :author, :repository
      t.timestamps
    end
  end

  def self.down
    drop_table :checkins
  end
end
