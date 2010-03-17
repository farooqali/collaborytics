require 'rbconfig'

module RSCM
  module Platform
    def family
      target_os = Config::CONFIG["target_os"] or ""
      return "powerpc-darwin" if target_os.downcase =~ /darwin/
      return "mswin32"  if target_os.downcase =~ /32/
      return "cygwin" if target_os.downcase =~ /cyg/
      return "freebsd" if target_os.downcase =~ /freebsd/
      raise "Unsupported OS: #{target_os}"
    end
    module_function :family
    
    def user
      family == "mswin32" ? ENV['USERNAME'] : ENV['USER']
    end
    module_function :user
    
    def prompt(dir=Dir.pwd)
      prompt = "#{dir.gsub(/\//, File::SEPARATOR)} #{user}$"
    end
    module_function :prompt
  end
end
