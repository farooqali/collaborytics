require 'rscm'
require 'forwardable'

class Checkin < ActiveRecord::Base
  belongs_to :repository
  
  def file_impact
    files_added + files_deleted + files_modified + files_moved
  end
  
  class << self
    def new_from(revision)
      checkin = Checkin.new :revision => revision.identifier, :checked_in_at => revision.time, 
                            :svn_log => revision.message, :login => revision.developer, 
                            :affected_paths => ""
      files = []
      revision.each { |file| files << file }
      checkin.affected_paths = files.collect(&:path).join("\n")
      checkin.files_added = files.select(&:added?).size
      checkin.files_deleted = files.select(&:deleted?).size
      checkin.files_modified = files.select(&:modified?).size
      checkin.files_moved = files.select(&:moved?).size
      checkin
    end
  end
end

class RSCM::RevisionFile
  def added?
    self.status == ADDED
  end
  
  def deleted?
    self.status == DELETED
  end
  
  def modified?
    self.status == MODIFIED
  end
  
  def moved?
    self.status == MOVED
  end
end