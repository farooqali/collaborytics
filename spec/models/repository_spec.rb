require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Repository do
  
  it "should be able to retrieve the first 2 checkins" do
    repo = Repository.new :url => "http://svn2.assembla.com/svn/fangorn/trunk/fangorn", :username => "faro00oq", :password => "95146krdfhsatrt"
    checkins = repo.discover_checkins(1..2)
    checkins.size.should == 2
  end
  
  it "should know how many files were added, deleted and modified in r214" do
    repo = Repository.new :url => "http://svn2.assembla.com/svn/fangorn/trunk/fangorn", :username => "faro00oq", :password => "95146krdfhsatrt"
    checkin = repo.discover_checkins(213)[0]
    checkin.files_added.should == 36
    checkin.files_deleted.should == 0
    checkin.files_modified.should == 12
  end
  
end
