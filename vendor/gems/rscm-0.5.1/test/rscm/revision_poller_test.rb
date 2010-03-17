require File.dirname(__FILE__) + '/test_helper'
require 'rscm/revision_poller'

module RSCM
  class FakeScm
    include RevisionPoller
    
    ra = Revision.new(1,   Time.utc(2004, 6,12,0,0,0))
    rb = Revision.new(120, Time.utc(2004, 7,12,0,0,0))
    range_x = Array.new(120, ra);  range_x[-1] = rb

    rc = Revision.new(121, Time.utc(2004, 8,12,0,0,0))
    rd = Revision.new(200, Time.utc(2004, 9,12,0,0,0))
    range_y = Array.new(80,  rc);  range_y[-1] = rd

    re = Revision.new(201, Time.utc(2004,10,12,0,0,0))
    rf = Revision.new(240, Time.utc(2004,11,12,0,0,0))
    range_z = Array.new(40,  re);  range_z[-1] = rf

    @@all_revisions = {}
    
    @@all_revisions[121] = Revisions.new(range_y)
    @@all_revisions[200] = Revisions.new(range_z)
    @@all_revisions[240] = Revisions.new()

    @@all_revisions[Time.utc(2004,12,11,23,0,0)] = Revisions.new(range_z) #  1 hr back from re (201-240)
    @@all_revisions[Time.utc(2004,10,11,22,0,0)] = Revisions.new(range_y) #  2 hr back from rc (121-200)
    @@all_revisions[Time.utc(2004, 8,11,20,0,0)] = Revisions.new(range_x) #  4 hr back from ra (1-120)
    @@all_revisions[Time.utc(2004, 6,11,20,0,0)] = Revisions.new()        #  8 hr back from ra
    @@all_revisions[Time.utc(2004, 6,11,16,0,0)] = Revisions.new()        # 16 hr back from ra
    @@all_revisions[Time.utc(2004, 6,11, 8,0,0)] = Revisions.new()        # etc...
    @@all_revisions[Time.utc(2004, 6,10,16,0,0)] = Revisions.new() 
    @@all_revisions[Time.utc(2004, 6, 9, 8,0,0)] = Revisions.new() 
    @@all_revisions[Time.utc(2004, 6, 6,16,0,0)] = Revisions.new() 
    @@all_revisions[Time.utc(2004, 6, 1, 8,0,0)] = Revisions.new() 
    @@all_revisions[Time.utc(2004, 5,21,16,0,0)] = Revisions.new() 
    @@all_revisions[Time.utc(2004, 4,30, 8,0,0)] = Revisions.new() 
    @@all_revisions[Time.utc(2004, 3,18,16,0,0)] = Revisions.new() 
    @@all_revisions[Time.utc(2003,12,24, 8,0,0)] = Revisions.new() 
    @@all_revisions[Time.utc(2003, 7, 6,16,0,0)] = Revisions.new() 
    @@all_revisions[Time.utc(2002, 7,30, 8,0,0)] = Revisions.new() 
    @@all_revisions[Time.utc(2000, 9,15,16,0,0)] = Revisions.new() 
    @@all_revisions[Time.utc(1996,12,20, 8,0,0)] = Revisions.new() 
    @@all_revisions[Time.utc(1989, 6,29,16,0,0)] = Revisions.new() 
    @@all_revisions[Time.utc(1974, 7,17, 8,0,0)] = Revisions.new() 
    @@all_revisions[Time.epoch]                  = Revisions.new() 
    
    def revisions(from, options)
      result = @@all_revisions[from]
      if result.nil?
        raise "No rev for time #{from.strftime('%Y,%m,%d,%H,%M,%S')}" if from.is_a?(Time)
        raise "No rev for rev #{from.inspect}" if from.is_a?(Revision)
      end
      result
    end
  end

  class RevisionPollerTest < Test::Unit::TestCase    
    def test_should_poll_backwards
      scm = FakeScm.new
      callback_count = 0
      scm.poll(Time.utc(2004,12,12,0,0,0), :backwards) do |revisions|
        callback_count += 1
      end
      assert_equal 21, callback_count
    end

    def test_should_poll_forwards
      scm = FakeScm.new
      callback_count = 0
      
      rc = Revision.new(121, Time.utc(2004, 8,12,0,0,0))
      now = Time.utc(2006, 4,12,11,51,43)
      scm.poll(rc, :forwards, 1, now) do |revisions|
        callback_count += 1
      end
      assert_equal 15, callback_count
    end
    
    def test_should_poll_forwards_upto_24_hours_from_identifier
      scm = FakeScm.new
      callback_count = 0
      
      now = Time.utc(2006, 4,12,11,51,43)
      scm.poll(240, :forwards, 1, now) do |revisions|
        callback_count += 1
      end
      assert_equal 6, callback_count
    end
  end
end
