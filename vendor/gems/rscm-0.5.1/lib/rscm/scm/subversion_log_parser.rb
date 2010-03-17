require 'rscm/parser'
require 'rscm/revision'
require 'rscm/revisions'
require 'rscm/revision_file'
require 'time'

module RSCM

  class SubversionLogParser
    def initialize(io, url, exclude_below_and_including=nil, exclude_above_and_including=nil, path=nil)
      @io = io
      @revision_parser = SubversionLogEntryParser.new(url, path)
      @exclude_below_and_including = exclude_below_and_including
      @exclude_above_and_including = exclude_above_and_including
    end
    
    def parse_revisions(&line_proc)
      # skip over the first ------
      @revision_parser.parse(@io, true, &line_proc)
      revisions = Revisions.new
      while(!@io.eof?)
        revision = @revision_parser.parse(@io, &line_proc)
        unless(revision.nil?)
          # Filter out the lower bound to avoid inclusiveness of the lower bound (see contract)
          # We're doing this instead of increasing the from_identifer with 1, since that causes an error.
          too_low = false
          too_high = false
          next if revision.time.nil?
          if(@exclude_below_and_including.is_a? Time)
            too_low = revision.time <= @exclude_below_and_including
          elsif(@exclude_below_and_including.is_a? Numeric)
            too_low = revision.identifier <= @exclude_below_and_including
          end

          if(@exclude_above_and_including.is_a? Time)
            too_high = revision.time >= @exclude_above_and_including
          elsif(@exclude_above_and_including.is_a? Numeric)
            too_high = revision.identifier >= @exclude_above_and_including
          end
          revisions.add(revision) unless too_low || too_high
        end
      end
      revisions
    end
  end
  
  class SubversionLogEntryParser < Parser

    def initialize(url, path=nil)
      super(/^------------------------------------------------------------------------/)
      @url = url
      @path = path
    end

    def parse(io, skip_line_parsing=false, &line_proc)
      # We have to trim off the last newline - it's not meant to be part of the message
      revision = super
      revision.message = revision.message[0..-2] if revision
      revision
    end

    def relative_path(url, path_from_root)
      path_from_root = path_from_root.chomp
      url_tokens = url.split('/')
      path_from_root_tokens = path_from_root.split('/')
      
      max_similar = path_from_root_tokens.length
      while(max_similar > 0)
        url = url_tokens[-max_similar..-1]
        path = path_from_root_tokens[0..max_similar-1]
        if(url == path)
          break
        end
        max_similar -= 1
      end

      if(max_similar == 0) 
        if(@path.nil? || @path == "")
          path_from_root
        else
          nil
        end
      else
        path_from_root_tokens[max_similar..-1].join("/")
      end
    end
    
  protected

    def parse_line(line)
      if(@revision.nil?)
        parse_header(line)
      elsif(line.strip == "")
        @parse_state = :parse_message
      elsif(line =~ /Changed paths/)
        @parse_state = :parse_files
      elsif(@parse_state == :parse_files)
        file = parse_file(line)
        if(file && file.path)
          previously_added_file = @revision[-1]
          if(previously_added_file)
            # remove previous revision_file if it's a dir
            previous_tokens = previously_added_file.path.split("/")
            current_tokens = file.path.split("/")
            current_tokens.pop
            if(previous_tokens == current_tokens)
              @revision.pop
            end
          end
          @revision.add file
        end
      elsif(@parse_state == :parse_message)
        @revision.message << line.chomp << "\n"
      end
    end

    def next_result
      result = @revision
      @revision = nil
      result
    end

  private
  
    STATES = {"M" => RevisionFile::MODIFIED, "A" => RevisionFile::ADDED, "D" => RevisionFile::DELETED} unless defined? STATES

    def parse_header(line)
      @revision = Revision.new
      @revision.message = ""
      revision, developer, time, the_rest = line.split("|")
      @revision.identifier = revision.strip[1..-1].to_i unless revision.nil?
      developer.strip!
      @revision.developer = developer unless developer.nil? || developer == "(no author)"
      time.strip!
      @revision.time = Time.parse(time).utc unless time.nil? || time == "(no date)"
    end
    
    def parse_file(line)
      file = RevisionFile.new
      path_from_root = nil
      if(line =~ /^   [M|A|D|R] ([^\s]+) \(from (.*)\)/)
        path_from_root = $1
        file.status = RevisionFile::MOVED
      elsif(line =~ /^   ([M|A|D|R]) (.+)$/)
        status = $1
        path_from_root = $2
        file.status = STATES[status]
      else
        raise "could not parse file line: '#{line}'"
      end

      path_from_root.gsub!(/\\/, "/")
      path_from_root = path_from_root[1..-1]
      rp = relative_path(@url, path_from_root)
      return if rp.nil?
      
      file.path = rp
      file.native_revision_identifier =  @revision.identifier
      # http://jira.codehaus.org/browse/DC-204
      file.previous_native_revision_identifier = file.native_revision_identifier.to_i - 1;
      file
    end
  end

end
