class Metric
  #TODO: determine this on the fly, perhaps something like define_metric :checkins {|checkins| checkins.size}
  ALL_METRICS = [:checkins, :file_impact, :contributors, :files_per_checkin]

  class << self
    def all_metrics
      ALL_METRICS
    end
    
    def checkins(checkins)
      checkins.size
    end
    
    def file_impact(checkins)
      checkins.inject(0) {|total, checkin| total += checkin.file_impact }
    end
    
    def contributors(checkins)
      checkins.collect(&:login).uniq.size
    end
    
    def files_per_checkin(checkins)
      checkins.empty?? 0 : file_impact(checkins) / checkins.size
    end
    
  end
end