module RSCM
  # Represents a file within a Revision, and also information about how this file
  # was modified compared with the previous revision.
  class RevisionFile

    MODIFIED = "MODIFIED"
    DELETED = "DELETED"
    ADDED = "ADDED"
    MOVED = "MOVED"
    
    # MODIFIED, DELETED, ADDED or MOVED
    attr_accessor :status
    
    # Relative path from the root of the RSCM::Base instance
    attr_accessor :path

    # The native SCM's previous revision for this file. For non-transactional SCMs this is different from
    # the parent Revision's 
    attr_accessor :previous_native_revision_identifier

    # The native SCM's revision for this file. For non-transactional SCMs this is different from
    # the parent Revision's 
    attr_accessor :native_revision_identifier

    # The developer who modified this file
    attr_accessor :developer
    
    # The commit message for this file
    attr_accessor :message
    
    # This is a UTC ruby time
    attr_accessor :time
    
    def initialize(path=nil, status=nil, developer=nil, message=nil, native_revision_identifier=nil, time=nil)
      @path, @developer, @message, @native_revision_identifier, @time, @status = path, developer, message, native_revision_identifier, time, status
    end
    
    def to_yaml_properties #:nodoc:
      # We remove properties that are duplicated in the parent revision.
      props = instance_variables
      props.delete("@developer")
      props.delete("@message")
      props.delete("@time")
      props.sort!
    end
    
    # Returns/yields an IO containing the contents of this file, using the +scm+ this
    # file lives in.
    def open(scm, options={}, &block) #:yield: io
      scm.open(path, native_revision_identifier, options, &block)
    end
    
    # Yields the diff as an IO for this file
    def diff(scm, options={}, &block)
      from_to = case status
        when /#{RevisionFile::MODIFIED}/; [previous_native_revision_identifier, native_revision_identifier]
        when /#{RevisionFile::DELETED}/; [previous_native_revision_identifier, nil]
        when /#{RevisionFile::ADDED}/; [nil, native_revision_identifier]
      end

      scm.diff(path, from_to[0], from_to[1], options, &block)
    end
  
    # Accepts a visitor that must respond to +visit_file(revision_file)+ 
    def accept(visitor)
      visitor.visit_file(self)
    end

    # A simple string representation. Useful for debugging.
    def to_s
      "#{path} | #{native_revision_identifier}"
    end

    def ==(other)
      return false if !other.is_a?(self.class)
      self.status == other.status &&
      self.path == other.path &&
      self.developer == other.developer &&
      self.message == other.message &&
      self.native_revision_identifier == other.native_revision_identifier &&
      self.time == other.time
    end
    
  end
end