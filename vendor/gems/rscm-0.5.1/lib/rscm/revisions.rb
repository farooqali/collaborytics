require 'rscm/time_ext'
require 'rscm/revision_file'

module RSCM

  # A Revisions object is a collection of Revision objects with some
  # additional behaviour.
  #
  # Most importantly, it provides logic to group individual RevisionFile
  # objects into Revision objects internally. This means that implementors
  # of RSCM adapters that don't support atomic changesets can still emulate 
  # them, simply by adding RevisionFile objects to a Revisions object. Example:
  #
  #   revisions = Revisions.new
  #   revisions.add revision_file_1
  #   revisions.add revision_file_2
  #   revisions.add revision_file_3
  #
  # The added RevisionFile objects will end up in Revision objects grouped by
  # their comment, developer and timestamp. A set of RevisionFile object with
  # identical developer and message will end up in the same Revision provided
  # their <tt>time</tt> attributes are a minute apart or less.
  #
  # Each Revisions object also has an attribute <tt>cmd</tt> which should contain
  # the command used to retrieve the revision data and populate it. This is useful
  # for debugging an RSCM adapter that might behaving incorrectly. Keep in mind that
  # it is the responsibility of each RSCM adapter implementation to set this attribute,
  # and that it should omit setting it if the <tt>store_revisions_command</tt> is
  # <tt>true</tt>
  class Revisions
    include Enumerable
    attr_accessor :cmd
    
    def initialize(revisions=[])
      @revisions = revisions
    end

    def add(file_or_revision)
      if(file_or_revision.is_a?(Revision))
        @revisions << file_or_revision
      else
        revision = find { |a_revision| a_revision.accept?(file_or_revision) }
        if(revision.nil?)
          revision = Revision.new
          @revisions << revision
        end
        revision.add file_or_revision
      end
    end
    
    def sort!
      @revisions.sort!{|r1,r2| r1.time<=>r2.time}
    end
        
    def to_s
      @revisions.collect{|revision| revision.to_s}.join("\n-----------")
    end
    
    def ==(other)
      self.to_s == other.to_s
    end
    
    def each(&block)
      @revisions.each(&block)
    end

    def [](n)
      @revisions[n]
    end

    def length
      @revisions.length
    end

    def empty?
      @revisions.empty?
    end
  end
end
