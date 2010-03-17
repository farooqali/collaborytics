require File.dirname(__FILE__) + '/test_helper'
require 'rscm/revision_file'

module RSCM
  class RevisionFileTest < Test::Unit::TestCase    
    def test_should_be_equal_when_data_equal
      assert_equal RevisionFile.new, RevisionFile.new
    end
  end
end
