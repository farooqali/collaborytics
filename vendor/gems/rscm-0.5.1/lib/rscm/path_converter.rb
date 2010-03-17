WIN32 = RUBY_PLATFORM == "i386-mswin32"
CYGWIN = RUBY_PLATFORM == "i386-cygwin"
WINDOWS = WIN32 || CYGWIN

require 'fileutils'

# Utility for converting between win32 and cygwin paths. Does nothing on *nix.
module RSCM
  module PathConverter
    def filepath_to_nativepath(path, escaped)
      return nil if path.nil?
      path = File.expand_path(path)
      if(WIN32)
        escaped ? path.gsub(/\//, "\\\\\\\\") : path.gsub(/\//, "\\")
      elsif(CYGWIN)
        cygpath = `cygpath --windows #{path}`.chomp
        escaped ? cygpath.gsub(/\\/, "\\\\\\\\") : cygpath
      else
        path
      end
    end
    module_function :filepath_to_nativepath

    def filepath_to_nativeurl(path)
      return nil if path.nil?
      if(WINDOWS)
        urlpath = filepath_to_nativepath(path, false).gsub(/\\/, "/")
        "file:///#{urlpath}"
      else
        "file://#{File.expand_path(path)}"
      end
    end
    module_function :filepath_to_nativeurl

    def nativepath_to_filepath(path)
      return nil if path.nil?
      path = File.expand_path(path)
      if(WIN32)
        path.gsub(/\//, "\\")
      elsif(CYGWIN)
        path = path.gsub(/\\/, "/")
        `cygpath --unix #{path}`.chomp
      else
        path
      end
    end
    module_function :nativepath_to_filepath
    
    def ensure_trailing_slash(url)
      return nil if url.nil?
      if(url && url[-1..-1] != "/")
        "#{url}/"
      else
        url
      end
    end
    module_function :ensure_trailing_slash

  end
end
