require File.dirname(__FILE__) + '/../test_helper'

module RSCM
  class PerforceTest < Test::Unit::TestCase
    compat(:rscm_engine)

    def test_dummy
      # need 1 test in case p4 is not installed (compat will not add tests)
    end
  end
end