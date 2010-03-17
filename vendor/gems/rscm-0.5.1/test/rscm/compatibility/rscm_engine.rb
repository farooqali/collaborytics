module RSCM
  module Compatibility
    # These tests verify that an RSCM adapter implementation will work with RscmEngine
    module RscmEngine
      include Difftool
    
      def setup
        config_yml = File.dirname(__FILE__) + '/config.yml'
        config = YAML::load_file(config_yml)
        raise "#{config_yml} must have an entry for #{self.class.name}" if config[self.class.name].nil?
        @testdata_dir = File.dirname(__FILE__) + '/' + config[self.class.name]
        raise "#{@testdata_dir} directory doesn't exist" unless File.directory?(@testdata_dir)
        @scm = YAML::load_file(@testdata_dir + '/scm.yml')
        @scm.store_revisions_command = false
      end
      
      def teardown
        begin
#          @scm.destroy_working_copy
        rescue => e
          STDERR.puts "WARN: #{e.message}"
        end
      end
      
      def test_should_get_revisions_by_revision_identifier
        suffix = "#{@scm.class.name}_#{method_name}".gsub(/:/, '_')
        do_verify_revisions_by_property(suffix, :identifier)
      end

      def test_should_get_revisions_by_time
        # Subversion 1.3.0 currently has an unresolved bug:
        # http://subversion.tigris.org/issues/show_bug.cgi?id=1642
        #
        # svn log http://buildpatterns.com/svn/repos/rscm/trunk/test/ --revision {"2006-03-03 11:55:55"}:{"2006-03-03 18:24:08"}
        #
        # returns revisions outside the lower bounds.
        # we therefore exclude this test when running svn tests - it's not that important since rscm_engine only uses timestamps
        # on the[0] run for a project, and it's not important that it is accurate.
        unless self.class.name == 'RSCM::SubversionTest'
          suffix = "#{@scm.class.name}_#{method_name}".gsub(/:/, '_')
          do_verify_revisions_by_property(suffix, :time)
        end
      end

      def do_verify_revisions_by_property(suffix, something)
        dir = File.expand_path(RSCM.new_temp_dir(suffix))
        options = {:stdout => "#{dir}/stdout.log", :stderr => "#{dir}/stderr.log"}.freeze
        @scm.checkout_dir = "#{dir}/checkout"

        expected_yaml = @testdata_dir + '/revisions.yml'
        expected = YAML::load_file(expected_yaml)

        # This should result in the same revisions [0]-1.[-1]+1)
        from = expected[0].__send__(something)-1
        to = expected[-1].__send__(something)+1
        opts = options.dup.merge :to_identifier => to
        actual = @scm.revisions(from, opts)
        actual.sort!

        if(expected != actual)
          assert_equal_with_diff(expected_yaml, actual.to_yaml, "See logs in #{dir}")
        end

        # This should NOT result in the same revisions [0].[-1]+1)
        from = expected[0].__send__(something)
        to = expected[-1].__send__(something)+1
        opts = options.dup.merge :to_identifier => to
        actual = @scm.revisions(from, opts)
        assert_not_equal(expected, actual)

        # This should NOT result in the same revisions [0]+1.[-1])
        from = expected[0].__send__(something)-1
        to = expected[-1].__send__(something)
        opts = options.dup.merge :to_identifier => to
        actual = @scm.revisions(from, opts)
        assert_not_equal(expected, actual)

      end
        
      def test_should_checkout_sources_to_particular_revision
        dirname = "#{@scm.class.name}_#{method_name}".gsub(/:/, '_')
        dir = File.expand_path(RSCM.new_temp_dir(dirname))
        options = {:stdout => "#{dir}/stdout.log", :stderr => "#{dir}/stderr.log"}.freeze
        revisions_yml = @testdata_dir + '/revisions.yml'
        revisions = YAML::load_file(revisions_yml)
        @scm.checkout_dir = RSCM.new_temp_dir("#{dirname}_0")
        files_0 = @scm.checkout(revisions[0].identifier, options)
        expected_yaml = @testdata_dir + "/files_0.yml"
        expected = YAML::load_file(expected_yaml)
        if(expected != files_0)
          assert_equal_with_diff(expected_yaml, files_0.to_yaml)
        end
        
        # We can predict what the next checked out files should be
        expected_files = files_0.dup
        revisions[1].each do |file|
          expected_files.delete(file.path) if file.status == "DELETED"
          expected_files.push(file.path) if file.status == "ADDED"
        end
        expected_files.sort!
        if(files_0 == expected_files)
          flunk "The 2nd revision in #{revisions_yml} must have at least one added or deleted file"
        end

        @scm.checkout_dir = RSCM.new_temp_dir("#{dirname}_1")
        files_1 = @scm.checkout(revisions[1].identifier, options)
        assert_equal(expected_files, files_1)

        # Now check out to the 1st revision again and verify files were removed
        added_paths = revisions[1].find_all{|rf| rf.status=="ADDED"}.collect{|rf| rf.path}
        assert added_paths.size > 0
        added_paths.each do |p|
          full_path = @scm.checkout_dir + '/' + p
          assert File.exist?(full_path), "Should exist: #{full_path}"
        end
        @scm.checkout(revisions[0].identifier, options)
        added_paths.each do |p|
          full_path = @scm.checkout_dir + '/' + p
          assert !File.exist?(full_path), "Should no longer exist: #{full_path}"
        end
      end
      
      def test_should_poll_old_revisions
        dirname = "#{@scm.class.name}_#{method_name}".gsub(/:/, '_')
        dir = File.expand_path(RSCM.new_temp_dir(dirname))
        options = {:stdout => "#{dir}/stdout.log", :stderr => "#{dir}/stderr.log"}.freeze
        @scm.checkout_dir = "#{dir}/checkout"

        old = YAML::load_file(@testdata_dir + '/old.yml')
      
        identifiers = []

        start = old['start']
        @scm.poll(start) do |revisions|
          identifiers << revisions.collect{|revision| revision.identifier}
        end
        identifiers.reverse!
        identifiers.flatten!

        expected_identifiers = old['identifiers']

        assert_equal(expected_identifiers, identifiers, "Expected identifiers from epoch to #{start} didn't match")
      end
      
      def test_should_find_diff
        dirname = "#{@scm.class.name}_#{method_name}".gsub(/:/, '_')
        dir = File.expand_path(RSCM.new_temp_dir(dirname))
        options = {:stdout => "#{dir}/stdout.log", :stderr => "#{dir}/stderr.log"}.freeze
        @scm.checkout_dir = "#{dir}/checkout"
        
        expected_yaml = @testdata_dir + '/revisions.yml'
        expected = YAML::load_file(expected_yaml)

        from = expected[0].identifier - 1
        to = expected[-1].identifier + 1
        opts = options.dup.merge :to_identifier => to
        revisions = @scm.revisions(from, opts)
        revisions.sort!
        
        # find the first modified file in the 0th revision
        modified_file = revisions[0].detect{|revision_file| revision_file.status == "MODIFIED"}
        
        # now run diff command
        diff = modified_file.diff(@scm, options) do |io|
          io.read
        end
        assert_equal_with_diff(@testdata_dir + "/diff.txt", diff)
      end

      def test_should_open_file
        dirname = "#{@scm.class.name}_#{method_name}".gsub(/:/, '_')
        dir = File.expand_path(RSCM.new_temp_dir(dirname))
        options = {:stdout => "#{dir}/stdout.log", :stderr => "#{dir}/stderr.log"}.freeze
        @scm.checkout_dir = "#{dir}/checkout"
        
        expected_yaml = @testdata_dir + '/revisions.yml'
        expected = YAML::load_file(expected_yaml)

        from = expected[0].identifier - 1
        to = expected[-1].identifier + 1
        opts = options.dup.merge :to_identifier => to
        revisions = @scm.revisions(from, opts)
        revisions.sort!
        
        # find the first modified file in the 0th revision
        modified_file = revisions[0].detect{|revision_file| revision_file.status == "MODIFIED"}
        
        # now run diff command
        file = modified_file.open(@scm, options) do |io|
          io.read
        end
        assert_equal_with_diff(@testdata_dir + "/file.txt", file)
      end

    end
  end
end