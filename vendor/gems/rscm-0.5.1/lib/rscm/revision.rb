require 'rscm/time_ext'
require 'rscm/revision_file'
require 'yaml'

module RSCM
  # Represents a collection of RevisionFile that were committed at the 
  # same time, or "more or less at the same time" for non-atomic 
  # SCMs (such as CVS and StarTeam). See Revisions for how to emulate
  # atomicity for non-atomic SCMs.
  class Revision
    include Enumerable

    attr_writer :identifier
    attr_accessor :developer
    attr_accessor :message
    
    def initialize(identifier=nil, time=nil)
      @identifier = identifier
      @time = time
      @files = []
    end

    def add(file)
      raise "Can't add #{file} to this revision" unless accept? file
      @files << file
      self.developer = file.developer if file.developer
      self.message = file.message if file.message
    end
    
    def identifier(min_or_max = :max)
      @identifier || time(min_or_max)
    end
    
    # The time of this revision. Depending on the value of +min_or_max+,
    # (should be :min or :max), returns the min or max time of this
    # revision. (min or max only matters for non-transactional scms)
    def time(min_or_max = :max)
      @time || self.collect{|file| file.time}.__send__(min_or_max)
    end

    # Sets the time for this revision. Should only be used by atomic SCMs.
    # Non-atomic SCMs should <b>not</b> invoke this method, but instead create
    # revisions by adding RscmFile objects to a Revisions object.
    def time=(t)
      raise "time must be a Time object - it was a #{t.class.name} with the string value #{t}" unless t.is_a?(Time)
      raise "can't set time to an inferiour value than the previous value" if @time && (t < @time)
      @time = t
    end
    
    # Whether +file+ can be added to this instance.
    def accept?(file) #:nodoc:
      return true if empty? || @time

      close_enough_to_min = (time(:min) - file.time).abs <= 60
      close_enough_to_max = (time(:max) - file.time).abs <= 60
      close_enough = close_enough_to_min or close_enough_to_max

      close_enough and
      self.developer == file.developer and
      self.message == file.message
    end

    def ==(other)
      self.to_s == other.to_s
    end

    # String representation that can be used for debugging.
    def to_s
      if(@to_s.nil?)
        min = time(:min)
        max = time(:max)
        t = (min==max) ? min : "#{min}-#{max}"
        @to_s = "#{identifier} | #{developer} | #{t} | #{message}\n"
        self.each do |file|
          @to_s << " " << file.to_s << "\n"
        end
        @to_s
      end
      @to_s
    end

    def each(&block)
      @files.each(&block)
    end

    def [](n)
      @files[n]
    end

    def length
      @files.length
    end

    def pop
      @files.pop
    end

    def empty?
      @files.empty?
    end

  end
end
