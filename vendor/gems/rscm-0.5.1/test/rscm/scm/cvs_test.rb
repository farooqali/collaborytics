require File.dirname(__FILE__) + '/../test_helper'

module RSCM
  class CvsTest < Test::Unit::TestCase
    compat(:rscm_engine, :full)
    
    def create_scm(repository_root_dir, path)
      Cvs.local(repository_root_dir, path)
    end

    def test_dummy
      # need 1 test in case p4 is not installed (compat will not add tests)
    end
  end

  class Cvs
    # Convenience factory method used in testing
    def Cvs.local(cvsroot_dir, mod)
      cvsroot_dir = PathConverter.filepath_to_nativepath(cvsroot_dir, true)
      Cvs.new(":local:#{cvsroot_dir}", mod)
    end
  end
  
end
