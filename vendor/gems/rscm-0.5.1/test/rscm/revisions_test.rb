require File.dirname(__FILE__) + '/test_helper'
require 'rscm/revision'
require 'rscm/revision_file'
require 'rscm/revisions'
require 'yaml'

module RSCM
  class RevisionsTest < Test::Unit::TestCase
    
    def setup
      @revision_file1 = RSCM::RevisionFile.new("path/one", "MODIFIED",   "aslak",   "Fixed CATCH-22", 2, Time.utc(2004,7,5,12,0,2))
      @revision_file2 = RSCM::RevisionFile.new("path/two", "MODIFIED",   "aslak",   "Fixed CATCH-22", 3, Time.utc(2004,7,5,12,1,2))
      @revision_file3 = RSCM::RevisionFile.new("path/three", "MODIFIED", "aslak",   "Fixed CATCH-22", 4, Time.utc(2004,7,5,12,2,3))
    end
    
    def test_adds_revision_files_to_revisions_as_needed
      revisions = Revisions.new
      revisions.add(@revision_file1)
      revisions.add(@revision_file2)
      revisions.add(@revision_file3)

      assert_equal(2, revisions.length)

      revision_0 = Revision.new
      revision_0.add @revision_file1
      revision_0.add @revision_file2
      
      revision_1 = Revision.new
      revision_1.add @revision_file3

      expected_revisions = Revisions.new
      expected_revisions.add revision_0
      expected_revisions.add revision_1

      assert_equal(expected_revisions, revisions)
    end
    
    def test_should_sort_by_time
      revisions = Revisions.new
      revisions.add(@revision_file3)
      revisions.add(@revision_file1)
      revisions.add(@revision_file2)
      
      revisions = revisions.sort do |a,b|
        a.time <=> b.time
      end
      assert_equal(2, revisions.length)

      assert_equal(@revision_file1.time, revisions[0].time(:min))
      assert_equal(@revision_file2.time, revisions[0].time)
      assert_equal(@revision_file3.time, revisions[1].time)
    end
    
    def test_should_be_equal_when_data_equal
      r1 = Revisions.new
      r1.add Revision.new

      r2 = Revisions.new
      r2.add Revision.new
    
      assert_equal r1, r2
    end
    
    def test_should_be_equal_after_yaml_serialization
      revisions = Revisions.new
      revisions.add(@revision_file3)
      revisions.add(@revision_file1)
      revisions.add(@revision_file2)
      
      revisions = revisions.sort do |a,b|
        a.time <=> b.time
      end

      cp = YAML::load(YAML::dump(revisions))
      assert_equal revisions[0][0].path, cp[0][0].path
    end
    
  end

end
