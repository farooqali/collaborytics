module RSCM
  module RevisionPoller
    attr_accessor :logger
  
    # This is the number of revisions we'll try to stick to for each
    # call to revisions.
    CRITICAL_REVISION_SIZE = 100
    BASE_INCREMENT = 60*60 # 1 hour
    TWENTY_FOUR_HOURS = 24*60*60
    
    # Polls revisions from +point+ and either backwards in time until the beginning 
    # of time (Time.epoch) or forward in time until we're past +now+.
    # 
    # Whether to poll forwards or backwards in time depends on the value of +direction+.
    #
    # The +point+ argument can be either a Revision, String, Time or Fixnum representing 
    # where to start from (upper boundary for backwards polling, lower boundary for
    # forwards polling).
    #
    # The polling starts with a small interval from +point+ (1 hour) and increments (or decrements)
    # gradually in order to try and keep the length of the yielded Revisions to about 100.
    #
    # The passed block will be called several times, each time with a Revisions object.
    # In order to reduce the memory footprint and keep the performance decent, the length
    # of each yielded Revisions object will usually be within the order of magnitude of 100.
    # 
    # TODO: handle non-transactional SCMs. There was some handling of this in older revisions
    # of this file. We should dig it out and reenable it.
    def poll(point=nil, direction=:backwards, multiplier=1, now=Time.now.utc, options={}, &proc)
      raise "A block of arity 1 must be called" if proc.nil?
      backwards = direction == :backwards      
      point ||= now
      
      if point.respond_to?(:time)
        point_time = backwards ? point.time(:min) : point.time(:max)
        point_identifier = backwards ? point.identifier(:min) : point.identifier(:max)
      elsif point.is_a?(Time)
        point_time = point
        point_identifier = point
      else
        point_time = now
        point_identifier = point
      end

      increment = multiplier * BASE_INCREMENT
      if backwards
        to = point_identifier
        begin
          from = point_time - increment
        rescue ArgumentError
          from = Time.epoch
        end
        from = Time.epoch if from < Time.epoch
      else
        from = point_identifier
        begin
          to = point_time + increment
        rescue RangeError
          raise "RSCM will not work this far in the future (#{from} plus #{increment})"
        end
      end

      options = options.merge({:to_identifier => to})

      revs = revisions(from, options)
      raise "Got nil revision for from=#{from.inspect}" if revs.nil?
      revs.sort!
      proc.call(revs)

      if from == Time.epoch
        return
      end
      if !backwards and to.is_a?(Time) and (to) > now + TWENTY_FOUR_HOURS
        return
      end

      if(revs.length < CRITICAL_REVISION_SIZE)
        # We can do more
        multiplier *= 2
      end
      if(revs.length > 2*CRITICAL_REVISION_SIZE)
        # We must do less
        multiplier /= 2
      end

      unless(revs.empty?)
        point = backwards ? revs[0] : revs[-1]
      end
      poll(point, direction, multiplier, now, options, &proc)
    end
    
  end
end