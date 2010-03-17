require 'test/unit'
$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../../lib')
$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../../test')
$LOAD_PATH.uniq!
require 'rscm'
require 'rscm/tempdir'
require 'rscm/compatibility/full'
require 'rscm/compatibility/rscm_engine'

module RSCM
  class Base
    DEFAULT_OPTIONS = {:stdout => 'target/stdout.log', :stderr => 'target/stderr.log'}.freeze unless defined? DEFAULT_OPTIONS

    def default_options
      DEFAULT_OPTIONS
    end
  end
end

module Test
  module Unit
    class TestCase
      SUITES = {
        :rscm_engine     => RSCM::Compatibility::RscmEngine,
        :full            => RSCM::Compatibility::Full
      } unless defined? SUITES

      # Call from scm adapter tests to have compatibility test suites included.
      def self.compat(*suite_keys)
        scm_class_name = self.name.match(/(.*)Test/)[1]
        scm_class = eval(scm_class_name)
        scm = scm_class.new
        if(scm.installed?)
          suite_keys.each do |key| 
            suite = SUITES[key]
            raise "The compat method arguments must be among #{SUITES.keys.join(', ')}" if suite.nil?

            STDERR.puts "INFO: Running #{suite} suite for #{scm_class_name}."
            include suite
          end
        else
          STDERR.puts "WARNING: Skipping #{suite} suite for #{scm_class_name}. It's not available."
        end
      end
    
    end
  end
end