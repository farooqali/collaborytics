# TODO
# Support int revision numbers AND dates
# Leverage default P4 client settings (optional)

require 'rscm/base'
require 'rscm/path_converter'
require 'rscm/line_editor'

require 'fileutils'
require 'time'
require 'socket'

module RSCM
  class Perforce < Base
    unless defined? DATE_FORMAT
      DATE_FORMAT = "%Y/%m/%d:%H:%M:%S"
      # Doesn't work for empty messages, (Like 21358 in Aslak's P4 repo)
      CHANGELIST_PATTERN = /^Change \d+ by (.*)@.* on (.*)\n\n(.*)\n\nAffected files ...\n\n(.*)/m
      # But this one does
      CHANGELIST_PATTERN_NO_MSG = /^Change \d+ by (.*)@.* on (.*)\n\nAffected files ...\n\n(.*)/m
      
      STATES = {
        "add" => RevisionFile::ADDED,
        "edit" => RevisionFile::MODIFIED,
        "delete" => RevisionFile::DELETED
      }
    end

    attr_accessor :view
    attr_accessor :username
    attr_accessor :password

    def installed?
      begin
        execute("p4 info", {}) 
        true
      rescue
        false
      end
    end

    def revisions(from_identifier=Time.new.utc, options={})
      raise "from_identifer cannot be nil" if from_identifier.nil?
      set_utc_offset(options)
      view_as_regexp = "^" + @view.gsub(/\.\.\./, "(.*)")
      relative_path_pattern = Regexp.new(view_as_regexp)
    
      from_identifier = Time.epoch unless from_identifier
      from_identifier = Time.epoch if (from_identifier.is_a? Time and from_identifier < Time.epoch)
      from = revision_spec(from_identifier + 1) # We have to add 1 because of the contract of this method.

      to_identifier = options[:to_identifier] ? options[:to_identifier] : Time.infinity
      to = revision_spec(to_identifier - 1) # We have to subtract 1 because of the contract of this method.

      cmd = "p4 #{p4_opts(false)} changes #{@view}@#{from},#{to}"
      revisions = Revisions.new
      revisions.cmd = cmd if store_revisions_command?

      changes = execute(cmd, options) do |io|
        io.read
      end

      changes.each do |line|
        revision = nil
        identifier = line.match(/^Change (\d+)/)[1].to_i

        execute("p4 #{p4_opts(false)} describe -s #{identifier}", options) do |io|
          log = io.read

          if log =~ CHANGELIST_PATTERN
            developer, time, message, files = $1, $2, $3, $4
          elsif log =~ CHANGELIST_PATTERN_NO_MSG
            developer, time, files = $1, $2, $3
          else
            puts "PARSE ERROR:"
            puts log
            puts "\nDIDN'T MATCH:"
            puts CHANGELIST_PATTERN
          end

          # The parsed time doesn't have timezone info. We'll tweak it.
          time = Time.parse(time + " UTC") - @utc_offset

          files.each_line do |line|
            if line =~ /^\.\.\. (\/\/.+)#(\d+) (.+)/
              depot_path = $1
              file_identifier = $2.to_i
              state = $3.strip
              if(STATES[state])
                if(depot_path =~ relative_path_pattern)
                  relative_path = $1

                  if revision.nil?
                    revision = Revision.new
                    revision.identifier = identifier
                    revision.developer = developer
                    revision.message = message
                    revision.time = time
                    revisions.add revision
                  end

                  file = RevisionFile.new
                  file.path = relative_path
                  file.native_revision_identifier = file_identifier
                  file.previous_native_revision_identifier = file.native_revision_identifier-1
                  file.status = STATES[state]
                  revision.add file
                end
              end
            end
          end
        end
      end
      revisions
    end
    
    def destroy_working_copy(options={})
      execute("p4 #{p4_opts(false)} client -d #{client_name}", options)
    end

    def open(revision_file, options={}, &block)
      path = @view.gsub(/\.\.\./, revision_file.path) # + "@" + revision_file.native_revision_identifier
      cmd = "p4 #{p4_opts(false)} print -q #{path}"
      execute(cmd, options) do |io|
        block.call io
      end
    end
    
    def diff
    #p4 diff2 //depot/trunk/build.xml@26405 //depot/trunk/build.xml@26409
    end

  protected

    def checkout_silent(to_identifier, options)
      checkout_dir = PathConverter.filepath_to_nativepath(@checkout_dir, false)
      FileUtils.mkdir_p(@checkout_dir)
      
      ensure_client(options)
      execute("p4 #{p4_opts} sync #{@view}@#{to_identifier}", options)
    end

    def ignore_paths
      []
    end
    
  private
  
    def p4_opts(with_client=true)
      user_opt = @username.to_s.empty? ? "" : "-u #{@username}"
      password_opt = @password.to_s.empty? ? "" : "-P #{@password}"
      client_opt = with_client ? "-c \"#{client_name}\"" : ""
      "#{user_opt} #{password_opt} #{client_opt}"
    end
    
    def client_name
      raise "checkout_dir not set" unless @checkout_dir
      Socket.gethostname + ":" + @checkout_dir
    end
    
    def ensure_client(options)
      create_client(options)
    end
    
    def create_client(options)
      options = {:mode => "w+"}.merge(options)
      FileUtils.mkdir_p(@checkout_dir)
      execute("p4 #{p4_opts(false)} client -i", options) do |io|
        io.puts(client_spec)
        io.close_write
      end
    end
    
    def client_spec
      <<-EOF
Client: #{client_name}
Owner: #{@username}
Host: #{Socket.gethostname}
Description: RSCM client
Root: #{@checkout_dir}
Options: noallwrite noclobber nocompress unlocked nomodtime normdir
LineEnd: local
View: #{@view} //#{client_name}/...
EOF
    end
    
    def revision_spec(identifier)
      if identifier.is_a?(Time)
        # The p4 client uses local time, but rscm uses utc
        # We have to convert to local time
        identifier += @utc_offset
        identifier.strftime(DATE_FORMAT)
      else
        identifier.to_i
      end
    end

    # Queries the server for the time offset. Required in order to get proper
    # timezone for revisions
    def set_utc_offset(options)
      unless @utc_offset
        execute("p4 #{p4_opts(false)} info", options) do |io|
          io.each do |line|
            if line =~ /^Server date: (.*)/
              server_time = Time.parse($1)
              @utc_offset = server_time.utc_offset
            end
          end
        end
        raise "Couldn't get server's UTC offset" if @utc_offset.nil?
      end
    end

  end

end
