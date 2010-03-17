require File.dirname(__FILE__) + '/test_helper'
require 'rscm/revision'
require 'rscm/revision_file'

module RSCM
  class RevisionTest < Test::Unit::TestCase    
    def test_accepts_files_in_range_and_reports_min_and_max
      revision = Revision.new
      
      revision.add RevisionFile.new(nil, nil, nil, nil, nil, Time.utc(2004,11,11,12,12,12))
      revision.add RevisionFile.new(nil, nil, nil, nil, nil, Time.utc(2004,11,11,12,13,12))
      assert_raise(RuntimeError) do
        revision.add RevisionFile.new(nil, nil, nil, nil, nil, Time.utc(2004,11,11,12,14,13))
      end
      
      t12 = Time.utc(2004,11,11,12,12,12)
      t13 = Time.utc(2004,11,11,12,13,12)
      assert_equal(t12, revision.time(:min))
      assert_equal(t13, revision.time(:max))
    end

    def test_should_be_equal_when_data_equal
      assert_equal Revision.new, Revision.new
    end
    
    def test_should_be_yamlable
      r1 = Revision.new
      r1.developer = "aslak"
      
      r2 = YAML::load(YAML::dump(r1))
      assert_equal r1.developer, r2.developer
    end
  end
end
