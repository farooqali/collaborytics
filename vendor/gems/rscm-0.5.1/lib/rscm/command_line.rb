require 'rscm/platform'

module RSCM
  module CommandLine
    QUOTE_REPLACEMENT = (Platform.family == "mswin32") ? "\"" : "\\\""
    LESS_THAN_REPLACEMENT = (Platform.family == "mswin32") ? "<" : "\\<"
    class OptionError < StandardError; end
    class ExecutionError < StandardError
      attr_reader :cmd, :dir, :exitstatus, :stderr      
      def initialize(cmd, full_cmd, dir, exitstatus, stderr)
        @cmd, @full_cmd, @dir, @exitstatus, @stderr = cmd, full_cmd, dir, exitstatus, stderr
      end
      def to_s
        "\ndir : #{@dir}\n" +
        "command : #{@cmd}\n" +
        "executed command : #{@full_cmd}\n" +
        "exitstatus: #{@exitstatus}\n" +
        "STDERR TAIL START\n#{@stderr}\nSTDERR TAIL END\n"
      end
    end
    
    # Executes +cmd+.
    # If the +:stdout+ and +:stderr+ options are specified, a line consisting
    # of a prompt (including +cmd+) will be appended to the respective output streams will be appended 
    # to those files, followed by the output itself. Example:
    #
    #   CommandLine.execute("echo hello world", {:stdout => "stdout.log", :stderr => "stderr.log"})
    #
    # will result in the following being written to stdout.log:
    #
    #   /Users/aslakhellesoy/scm/buildpatterns/repos/damagecontrol/trunk aslakhellesoy$ echo hello world
    #   hello world
    #
    # -and to stderr.log:
    #   /Users/aslakhellesoy/scm/buildpatterns/repos/damagecontrol/trunk aslakhellesoy$ echo hello world
    #
    # If a block is passed, the stdout io will be yielded to it (as with IO.popen). In this case the output
    # will not be written to the stdout file (even if it's specified):
    #
    #   /Users/aslakhellesoy/scm/buildpatterns/repos/damagecontrol/trunk aslakhellesoy$ echo hello world
    #   [output captured and therefore not logged]
    #
    # If the exitstatus of the command is different from the value specified by the +:exitstatus+ option
    # (which defaults to 0) then an ExecutionError is raised, its message containing the last 400 bytes of stderr 
    # (provided +:stderr+ was specified)
    #
    # You can also specify the +:dir+ option, which will cause the command to be executed in that directory
    # (default is current directory).
    #
    # You can also specify a hash of environment variables in +:env+, which will add additional environment variables
    # to the default environment.
    # 
    # Finally, you can specify several commands within one by separating them with '&&' (as you would in a shell).
    # This will result in several lines to be appended to the log (as if you had executed the commands separately).
    #
    # See the unit test for more examples.
    def execute(cmd, options={}, &proc)
      raise "Can't have newline in cmd" if cmd =~ /\n/
      options = {
        :dir => Dir.pwd,
        :env => {},
        :mode => 'r',
        :exitstatus => 0
      }.merge(options)
      
      options[:stdout] = File.expand_path(options[:stdout]) if options[:stdout]
      options[:stderr] = File.expand_path(options[:stderr]) if options[:stderr]

      if options[:dir].nil?
        e(cmd, options, &proc)
      else
        Dir.chdir(options[:dir]) do
          e(cmd, options, &proc)
        end
      end
    end
    module_function :execute

  private

    def full_cmd(cmd, options, &proc)
      commands = cmd.split("&&").collect{|c| c.strip}
      stdout_opt = options[:stdout] ? ">> #{options[:stdout]}" : ""
      stderr_opt = options[:stderr] ? "2>> #{options[:stderr]}" : ""
      capture_info_command = (block_given? && options[:stdout])? "echo [output captured and therefore not logged] >> #{options[:stdout]} && " : ""

      full_cmd = commands.collect do |c|
        escaped_command = c.gsub(/"/, QUOTE_REPLACEMENT).gsub(/</, LESS_THAN_REPLACEMENT)
        stdout_prompt_command = options[:stdout] ? "echo #{RSCM::Platform.prompt} #{escaped_command} >> #{options[:stdout]} && " : ""
        stderr_prompt_command = options[:stderr] ? "echo #{RSCM::Platform.prompt} #{escaped_command} >> #{options[:stderr]} && " : ""
        redirected_command = block_given? ? "#{c} #{stderr_opt}" : "#{c} #{stdout_opt} #{stderr_opt}"

        stdout_prompt_command + capture_info_command + stderr_prompt_command + redirected_command
      end.join(" && ")
    end
    module_function :full_cmd

    def verify_exit_code(cmd, full_cmd, options)
      if($?.exitstatus != options[:exitstatus])
        error_message = "#{options[:stderr]} doesn't exist"
        if options[:stderr] && File.exist?(options[:stderr])
          File.open(options[:stderr]) do |errio|
            begin
              errio.seek(-1200, IO::SEEK_END)
            rescue Errno::EINVAL
              # ignore - it just means we didn't have 400 bytes.
            end
            error_message = errio.read
          end
        end
        raise ExecutionError.new(cmd, full_cmd, options[:dir] || Dir.pwd, $?.exitstatus, error_message)
      end
    end
    module_function :verify_exit_code

    def e(cmd, options, &proc)
      full_cmd = full_cmd(cmd, options, &proc)

      options[:env].each{|k,v| ENV[k]=v}
      begin
        STDOUT.puts "#{RSCM::Platform.prompt} #{cmd}" if options[:stdout].nil?
        IO.popen(full_cmd, options[:mode]) do |io|
          if(block_given?)
            proc.call(io)
          else
            io.each_line do |line|
              STDOUT.puts line if options[:stdout].nil?
            end
          end
        end
      rescue Errno::ENOENT => e
        unless options[:stderr].nil?
          File.open(options[:stderr], "a") {|io| io.write(e.message)}
        else
          STDERR.puts e.message
          STDERR.puts e.backtrace.join("\n")
        end
        raise ExecutionError.new(cmd, full_cmd, options[:dir] || Dir.pwd, nil, e.message)
      ensure
        verify_exit_code(cmd, full_cmd, options)
      end
    end
    module_function :e

  end
end