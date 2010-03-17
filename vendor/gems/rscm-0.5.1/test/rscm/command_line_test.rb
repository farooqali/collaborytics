require File.dirname(__FILE__) + '/test_helper'
require 'rscm/command_line'

module RSCM

  class CommandLineTest < Test::Unit::TestCase
    def setup_dir(prefix)
      @dir = RSCM.new_temp_dir(prefix)
      @stdout = "#{@dir}/stdout"
      @stderr = "#{@dir}/stderr"
      @prompt = "#{File.expand_path(@dir)} #{Platform.user}$"
      File.delete @stdout if File.exist? @stdout
      File.delete @stderr if File.exist? @stderr
    end

    def test_should_write_to_both_files_when_both_files_specified_and_no_block
      setup_dir(method_name)
      CommandLine.execute("echo \"<hello\" && echo world", {:dir => @dir, :stdout => @stdout, :stderr => @stderr})
      assert_match(/.* echo \"<hello\"\s*\n.?\<hello.?\s*\n.* echo world\s*\nworld/n, File.open(@stdout).read)
      assert_match(/.* echo \"<hello\"\s*\n.* echo world\s*/n, File.open(@stderr).read)
    end
    
    def test_should_not_write_to_stdout_file_when_no_stdout_specified
      setup_dir(method_name)
      orgout = STDOUT.dup
      STDOUT.reopen(@stdout)
      CommandLine.execute("echo hello", {:dir => @dir, :stderr => @stderr})
      STDOUT.reopen(orgout)
      assert_equal("#{@prompt} echo hello\nhello", File.open(@stdout).read.strip)
      assert_equal("#{@prompt} echo hello", File.open(@stderr).read.strip)
    end
    
    def test_should_only_write_command_to_stdout_when_block_specified
      setup_dir(method_name)
      CommandLine.execute("echo hello", {:dir => @dir, :stdout => @stdout, :stderr => @stderr}) do |io|
        assert_equal("hello", io.read.strip)
      end
      assert_match(/.* echo hello\s*\[output captured and therefore not logged\]/n, File.open(@stdout).read.strip)
      assert_equal("#{@prompt} echo hello", File.open(@stderr).read.strip)
    end
    
    def test_should_raise_on_bad_command
      setup_dir(method_name)
      assert_raise(CommandLine::ExecutionError) do
        CommandLine.execute("xaswedf", {:dir => @dir, :stdout => @stdout, :stderr => @stderr})
      end
    end

    def test_should_raise_on_bad_command_with_block
      setup_dir(method_name)
      assert_raise(CommandLine::ExecutionError) do
        CommandLine.execute("xaswedf", {:dir => @dir, :stdout => @stdout, :stderr => @stderr}) do |io|
          io.each_line do |line|
          end
        end
      end
    end

    def test_should_return_block_result
      setup_dir(method_name)
      result = CommandLine.execute("echo hello", {:dir => @dir, :stdout => @stdout, :stderr => @stderr}) do |io|
        io.read
      end
      assert_equal "hello", result.strip
    end

  end
end