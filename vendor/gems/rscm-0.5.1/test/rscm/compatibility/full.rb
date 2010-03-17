require 'fileutils'
require 'rscm/tempdir'
require 'rscm/path_converter'
require 'rscm/difftool'

module RSCM 
module Compatibility
  module Full
    
    include FileUtils

    def teardown
      if @scm
        begin
#          @scm.destroy_working_copy
#          @scm.destroy_central
        rescue => e
          # Fails on windows with TortoiseCVS' cvs because of resident cvslock.exe
          STDERR.puts "Couldn't destroy central #{@scm.class.name}: #{e.message}"
        end
      end
    end


    def test_create_destroy
      work_dir = RSCM.new_temp_dir("create_destroy")
      checkout_dir = "#{work_dir}/checkout"
      repository_dir = "#{work_dir}/repository"
      scm = create_scm(repository_dir, "killme")
      scm.checkout_dir = checkout_dir

      (1..3).each do
        assert(!scm.central_exists?)
        scm.create_central 
        assert(scm.central_exists?)
        scm.destroy_central
      end

      assert(!scm.central_exists?)
    end
    
    def test_trigger
      work_dir = RSCM.new_temp_dir("trigger")
      checkout_dir = "#{work_dir}/checkout"
      repository_dir = "#{work_dir}/repository"
      trigger_proof = "#{work_dir}/trigger_proof"
      scm = create_scm(repository_dir, "damagecontrolled")
      scm.checkout_dir = checkout_dir
      scm.create_central 
      @scm = scm
      
      # Verify that install/uninstall works
      touch = WINDOWS ? PathConverter.filepath_to_nativepath(File.dirname(__FILE__) + "/../../../bin/touch.exe", true) : `which touch`.strip
      trigger_command = touch + " " + PathConverter.filepath_to_nativepath(trigger_proof, true)
      trigger_files_checkout_dir = File.expand_path("#{checkout_dir}/../trigger")
      (1..3).each do |i|
        assert(!scm.trigger_installed?(trigger_command, trigger_files_checkout_dir))
        scm.install_trigger(trigger_command, trigger_files_checkout_dir)
        assert(scm.trigger_installed?(trigger_command, trigger_files_checkout_dir))
        scm.uninstall_trigger(trigger_command, trigger_files_checkout_dir)
      end

      # Verify that the trigger works
      import_damagecontrolled(scm, "#{work_dir}/damagecontrolled")
      scm.checkout nil
      scm.install_trigger(trigger_command, trigger_files_checkout_dir)
      assert(!File.exist?(trigger_proof))

      add_or_edit_and_commit_file(scm, checkout_dir, "afile", "boo")
      assert(File.exist?(trigger_proof))
    end

    def test_should_move
      work_dir = RSCM.new_temp_dir("move")
      checkout_dir = "#{work_dir}/checkout"
      repository_dir = "#{work_dir}/repository"
      scm = create_scm(repository_dir, "damagecontrolled")
      scm.checkout_dir = checkout_dir
      scm.create_central 
      @scm = scm

      import_damagecontrolled(scm, "#{work_dir}/damagecontrolled")
      scm.checkout nil
      
      from = "src/java/com/thoughtworks/damagecontrolled/Thingy.java"
      to = "src/java/com/thoughtworks/damagecontrolled/Mooky.java"
      scm.move(from, to)
      scm.commit("Moved a file")
      assert(File.exist?(scm.checkout_dir + "/" + to))
      rm_rf(scm.checkout_dir + "/" + to)
      assert(!File.exist?(scm.checkout_dir + "/" + to))
      scm.checkout nil
      assert(File.exist?(scm.checkout_dir + "/" + to))
    end

    def test_should_allow_creation_with_empty_constructor
      scm = create_scm(RSCM.new_temp_dir, ".")
      scm2 = scm.class.new
      assert_same(scm.class, scm2.class)
    end

  private

    def import_damagecontrolled(scm, import_copy_dir)
      mkdir_p(import_copy_dir)
      path = File.dirname(__FILE__) + "/../../../testproject/damagecontrolled"
      path = File.expand_path(path)
      dirname = File.dirname(import_copy_dir)
      cp_r(path, dirname)
      todelete = Dir.glob("#{import_copy_dir}/**/.svn")
      rm_rf(todelete)
      scm.import_central import_copy_dir, :message => "imported sources"
    end
    
    def change_file(scm, file)
      file = File.expand_path(file)
      scm.edit(file)
      File.open(file, "w+") do |io|
        io.puts("changed\n")
      end
    end

    def add_or_edit_and_commit_file(scm, checkout_dir, relative_filename, content)
      existed = false
      absolute_path = File.expand_path("#{checkout_dir}/#{relative_filename}")
      File.mkpath(File.dirname(absolute_path))
      existed = File.exist?(absolute_path)
      File.open(absolute_path, "w") do |file|
        file.puts(content)
      end
      scm.add(relative_filename) unless existed

      message = existed ? "editing" : "adding"

      sleep(1)
      scm.commit("#{message} #{relative_filename}")
    end
  end
    
  module LabelTest
    def test_label
      work_dir = RSCM.new_temp_dir("label")
      checkout_dir = "#{work_dir}/LabelTest"
      repository_dir = "#{work_dir}/repository"
      scm = create_scm(repository_dir, "damagecontrolled")
      scm.checkout_dir = checkout_dir
      scm.create_central 
      @scm = scm

      import_damagecontrolled(scm, "#{work_dir}/damagecontrolled")

      scm.checkout nil

      # TODO: introduce a Revision class which implements comparator methods
      return
      assert_equal(
        "1",
        scm.label 
      )
      change_file(scm, "#{checkout_dir}/build.xml")
      scm.commit("changed something")
      scm.checkout nil
      assert_equal(
        "2",
        scm.label 
      )
    end
  end
end
end
