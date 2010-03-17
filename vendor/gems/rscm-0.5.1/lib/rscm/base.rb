require 'fileutils'
require 'rscm/revision'
require 'rscm/path_converter'

module RSCM
  # This class defines the RSCM API, which offers access to an SCM working copy
  # as well as a 'central' repository.
  #
  # Concrete subclasses of this class (concrete adapters) implement the integration
  # with the respective SCMs.
  #
  # Most of the methods take an optional +options+ Hash (named parameters), allowing
  # the following options:
  #
  # * <tt>:stdout</tt>: Path to file name where stdout of SCM operations are written.
  # * <tt>:stdout</tt>: Path to file name where stderr of SCM operations are written.
  #
  # In stead of specifying the +options+ parameters for every API method, it's possible
  # to assign default options via the +default_options+ attribute.
  #
  # Some of the methods in this API use +from_identifier+ and +to_identifier+.
  # These identifiers can be either a UTC Time (according to the SCM's clock)
  # or a String or Integer representing a label/revision 
  # (according to the SCM's native label/revision scheme).
  #
  # If +from_identifier+ or +to_identifier+ are +nil+ they should respectively default to
  # Time.epoch or Time.infinite.
  #
  class Base
    include RevisionPoller
  
    attr_writer :default_options
    attr_writer :store_revisions_command

    def default_options
      @default_options ||= {}
    end
  
    # Returns true if the underlying SCM tool is available on this system.
    def available?
      raise NotImplementedError
    end

    # Transforms +raw_identifier+ into the native rype used for revisions.
    def to_identifier(raw_identifier)
      raw_identifier.to_s
    end
  
    # Sets the checkout dir (working copy). Should be set prior to most other method
    # invocations (depending on the implementation).
    def checkout_dir=(dir)
      @checkout_dir = PathConverter.filepath_to_nativepath(dir, false)
    end
  
    # Gets the working copy directory.
    def checkout_dir
      @checkout_dir
    end

    def to_yaml_properties #:nodoc:
      props = instance_variables
      props.delete("@checkout_dir")
      props.delete("@default_options")
      props.sort!
    end

    # Destroys the working copy
    def destroy_working_copy(options={})
      FileUtils.rm_rf(checkout_dir) unless checkout_dir.nil?
    end

    # Whether or not the SCM represented by this instance exists.
    def central_exists?
      # The default implementation assumes yes - override if it can be
      # determined programmatically.
      true
    end
    
    # Whether or not this SCM is transactional (atomic).
    def transactional?
      false
    end
    alias :atomic? :transactional?

    # Creates a new 'central' repository. This is intended only for creation of 'central'
    # repositories (not for working copies). You shouldn't have to call this method if a central repository
    # already exists. This method is used primarily for testing of RSCM, but can also
    # be used if you *really* want to use RSCM to create a central repository. 
    # 
    # This method should throw an exception if the repository cannot be created (for
    # example if the repository is 'remote' or if it already exists).
    #
    def create_central(options={})
      raise NotImplementedError
    end
    
    # Destroys the central repository. Shuts down any server processes and deletes the repository.
    # WARNING: calling this may result in loss of data. Only call this if you really want to wipe 
    # it out for good!
    def destroy_central
      raise NotImplementedError
    end

    # Whether a repository can be created.
    def can_create_central?
      false
    end

    # Adds +relative_filename+ to the working copy.
    def add(relative_filename, options={})
      raise NotImplementedError
    end

    # Schedules a move of +relative_src+ to +relative_dest+
    # Should not take effect in the central repository until
    # +commit+ is invoked.
    def move(relative_src, relative_dest, options={})
      raise NotImplementedError
    end

    # Recursively imports files from <tt>:dir</tt> into the central scm,
    # using commit message <tt>:message</tt>
    def import_central(options)
      raise NotImplementedError
    end

    # Open a file for edit - required by scms that check out files in read-only mode e.g. perforce
    def edit(file, options={})
    end
    
    # Commit (check in) modified files.
    def commit(message, options={})
      raise NotImplementedError
    end
    
    # Checks out or updates contents from a central SCM to +checkout_dir+ - a local working copy.
    # If this is a distributed SCM, this method should create a 'working copy' repository
    # if one doesn't already exist. Then the contents of the central SCM should be pulled into
    # the working copy.
    #
    # The +to_identifier+ parameter may be optionally specified to obtain files up to a
    # particular time or label. +to_identifier+ should either be a Time (in UTC - according to
    # the clock on the SCM machine) or a String - reprsenting a label or revision.
    #
    # This method will yield the relative file name of each checked out file, and also return
    # them in an array. Only files, not directories, should be yielded/returned.
    #
    # This method should be overridden for SCMs that are able to yield checkouts as they happen.
    # For some SCMs this is not possible, or at least very hard. In that case, just override
    # the checkout_silent method instead of this method (should be protected).
    #
    def checkout(to_identifier=Time.infinity, options={}) # :yield: file
      to_identifier = Time.infinity if to_identifier.nil?

      before = checked_out_files
      # We expect subclasses to implement this as a protected method (unless this whole method is overridden).
      checkout_silent(to_identifier, options)
      after = checked_out_files
      
      (after - before).sort!
    end
    
    def checked_out_files
      raise "checkout_dir not set" if @checkout_dir.nil?

      files = Dir["#{@checkout_dir}/**/*"]
      files.delete_if{|file| File.directory?(file)}
      ignore_paths.each do |regex|
        files.delete_if{|file| file =~ regex}
      end
      dir = File.expand_path(@checkout_dir)
      files.collect{|file| File.expand_path(file)[dir.length+1..-1]}
    end
  
    # Returns a Revisions object for the interval specified by +from_identifier+ (exclusive, i.e. after)
    # and optionally +:to_identifier+ (exclusive too). If +relative_path+ is specified, the result will only contain
    # revisions pertaining to that path.
    #
    # For example, revisions(223, 229) should return revisions 224..228
    def revisions(from_identifier, options={})
      raise NotImplementedError
    end
    
    # Opens a readonly IO to a file at +path+
    def open(path, native_revision_identifier, options={}, &block) #:yield: io
      raise NotImplementedError
    end

    # Whether the working copy is in synch with the central
    # repository's revision/time identified by +identifier+. 
    # If +identifier+ is nil, 'HEAD' of repository should be assumed.
    #
    def uptodate?(identifier)
      raise NotImplementedError
    end

    # Whether the project is checked out from the central repository or not.
    # Subclasses should override this to check for SCM-specific administrative
    # files if appliccable
    def checked_out?
      File.exists?(@checkout_dir)
    end

    # Whether triggers are supported by this SCM. A trigger is a command that can be executed
    # upon a completed commit to the SCM.
    def supports_trigger?
      # The default implementation assumes no - override if it can be
      # determined programmatically.
      false
    end
    alias :can_install_trigger? :supports_trigger?

    # Descriptive name of the trigger mechanism
    def trigger_mechanism
      raise NotImplementedError
    end

    # Installs +trigger_command+ in the SCM.
    # The +install_dir+ parameter should be an empty local
    # directory that the SCM can use for temporary files
    # if necessary (CVS needs this to check out its administrative files).
    # Most implementations will ignore this parameter.
    #
    def install_trigger(trigger_command, install_dir)
      raise NotImplementedError
    end

    # Uninstalls +trigger_command+ from the SCM.
    #
    def uninstall_trigger(trigger_command, install_dir)
      raise NotImplementedError
    end

    # Whether the command denoted by +trigger_command+ is installed in the SCM.
    #
    def trigger_installed?(trigger_command, install_dir)
      raise NotImplementedError
    end

    # The command line to run in order to check out a fresh working copy.
    #
    def checkout_commandline(to_identifier=Time.infinity)
      raise NotImplementedError
    end

    # The command line to run in order to update a working copy.
    #
    def update_commandline(to_identifier=Time.infinity)
      raise NotImplementedError
    end

    # Yields an IO containing the unified diff of the change.
    # Also see RevisionFile#diff
    def diff(path, from, to, options={}, &block)
      raise NotImplementedError
    end

    def ==(other_scm)
      return false if self.class != other_scm.class
      self.instance_variables.each do |var|
        return false if self.instance_eval(var) != other_scm.instance_eval(var)
      end
      true
    end
    
    # Whether or not to store the revision command in the Revisions instance returned by <tt>revisions</tt>
    def store_revisions_command?; @store_revisions_command.nil? ? true : @store_revisions_command; end
    
  protected

    # Directory where commands must be run
    def cmd_dir
      nil
    end

    # Wrapper for CommandLine.execute that provides default values for 
    # dir plus any options set in default_options (typically stdout and stderr).
    def execute(cmd, options={}, &proc)
      options = {:dir => cmd_dir}.merge(default_options).merge(options)
      begin
        CommandLine.execute(cmd, options, &proc)
      rescue CommandLine::OptionError => e
        e.message += "\nEither specify default_options on the scm object, or pass the required options to the method"
        raise e
      end
    end

  end
end
