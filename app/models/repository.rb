require 'rscm'

class Repository < ActiveRecord::Base
  has_many :checkins, :dependent => :destroy
  
  def after_initialize
    @scm = RSCM::Subversion.new url
    @scm.username = username
    @scm.password = password
  end
  
  def contributors
    checkins.collect(&:login).uniq.reject(&:blank?)
  end
  
  def discover_checkins(revision_numbers = nil)
    if revision_numbers.nil?
      revisions = @scm.revisions(1)
      checkins = []
      revisions.each do |revision|
        print "#{revision.identifier}, "
        checkin = Checkin.new_from(revision)
        checkin.repository = self
        checkins << checkin
        checkin.save!
        puts "Checkin #{checkin.reload.revision} confirmed" if Checkin.find_by_revision(checkin.revision)
      end
      return checkins
    end
    
    revision_numbers ||= (1..head_revision_number)
    revision_numbers = [*revision_numbers]
    revision_numbers.collect do |revision_number| 
      revisions = @scm.revisions(revision_number)
      Checkin.new_from(revisions[0])
    end
  end
  
  def head_revision_number
    @scm.send(:head_revision_identifier, {})
  end
end