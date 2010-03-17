require 'rscm/tempdir'
require 'rscm/path_converter'
require 'rscm/difftool'

module RSCM
  module Difftool
    # assertion method that reports differences as diff.
    # useful when comparing big strings
    def assert_equal_with_diff(expected, actual, message="", temp_basedir=File.dirname(__FILE__) + "/../../target")
      diff(expected, actual, temp_basedir) do |diff_io, cmd|
        diff_string = diff_io.read
        if(diff_string.strip != "")
          flunk "#{message}\nThere were differences\ndiff command: #{cmd}\ndiff:\n#{diff_string}"
        end
      end
    end
    module_function :assert_equal_with_diff
  
    def diff(expected, actual, temp_basedir, &block)
      dir = RSCM.new_temp_dir("diff", temp_basedir)

      expected_file = nil
      if(File.exist?(expected))
        expected_file = expected
      else
        expected_file = "#{dir}/expected"
        File.open(expected_file, "w") {|io| io.write(expected)}
      end

      actual_file = "#{dir}/actual"
      File.open(actual_file, "w") {|io| io.write(actual)}

      difftool = WINDOWS ? File.dirname(__FILE__) + "/../../bin/diff.exe" : "diff"
      e = RSCM::PathConverter.filepath_to_nativepath(expected_file, false)
      a = RSCM::PathConverter.filepath_to_nativepath(actual_file, false)
      cmd = "#{difftool} --ignore-space-change #{e} #{a}"
      IO.popen(cmd) do |io|
        yield io, cmd
      end
    end
    module_function :diff

  end
end
