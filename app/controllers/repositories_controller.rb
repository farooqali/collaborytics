class RepositoriesController < ApplicationController
  TEAM_IDENTIFIER = '[Team]'
  # GET /repositories
  # GET /repositories.xml
  def index
    @repositories = Repository.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @repositories }
    end
  end

  # GET /repositories/1
  # GET /repositories/1.xml
  def show
    # view configuration
    @repository = Repository.find(params[:id])
    @all_contributors = @repository.contributors.unshift(TEAM_IDENTIFIER)
    @selected_contributors = (params[:contributors] || [TEAM_IDENTIFIER]) & @all_contributors #only allow valid contributors
    @start_date, @end_date = start_date_param, end_date_param
    @date_range = @start_date..@end_date
    @selected_metric = params[:metric] || :checkins
    @show_annotations = params[:show_annotations] == 'true'
    
    # scoped data retrieval
    @checkins = @repository.checkins.find(:all, :conditions => ["checked_in_at >= ? and checked_in_at <= ? and login in (?)", 
                                                                @start_date, @end_date, @selected_contributors.include?(TEAM_IDENTIFIER) ? @all_contributors : @selected_contributors])
    
    # roll up results
    @checkins_by_date = @checkins.group_by{|c|c.checked_in_at.to_date}
    checkins_by_contributor = @checkins.group_by(&:login)
    checkins_by_contributor.delete_if {|login,checkins| !@selected_contributors.include?(login)}
    @checkins_by_contributor_by_date = {}
    checkins_by_contributor.each do |contributor, checkins|
      checkins_by_date = checkins.group_by{|c|c.checked_in_at.to_date}
      @checkins_by_contributor_by_date[contributor] = checkins_by_date
    end
    if @selected_contributors.include?(TEAM_IDENTIFIER)
      @checkins_by_contributor_by_date[TEAM_IDENTIFIER] = @checkins_by_date
    end
    
    # render
    respond_to do |format|c
      format.html # show.html.erb
      format.xml  { render :xml => @repository }
    end
  end
  
  def start_date_param
    start_date = params[:date_range].split('-')[0]
    Date.parse(start_date)
  rescue
    1.month.ago.to_date
  end
  
  def end_date_param
    end_date = params[:date_range].split('-')[1]
    Date.parse(end_date)
  rescue
    Date.tomorrow
  end

  # GET /repositories/new
  # GET /repositories/new.xml
  def new
    @repository = Repository.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @repository }
    end
  end

  # GET /repositories/1/edit
  def edit
    @repository = Repository.find(params[:id])
  end

  # POST /repositories
  # POST /repositories.xml
  def create
    @repository = Repository.new(params[:repository])

    respond_to do |format|
      if @repository.save
        flash[:notice] = 'Repository was successfully created.'
        format.html { redirect_to(@repository) }
        format.xml  { render :xml => @repository, :status => :created, :location => @repository }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @repository.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /repositories/1
  # PUT /repositories/1.xml
  def update
    @repository = Repository.find(params[:id])

    respond_to do |format|
      if @repository.update_attributes(params[:repository])
        flash[:notice] = 'Repository was successfully updated.'
        format.html { redirect_to(repositories_path) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @repository.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /repositories/1
  # DELETE /repositories/1.xml
  def destroy
    @repository = Repository.find(params[:id])
    @repository.destroy

    respond_to do |format|
      format.html { redirect_to(repositories_url) }
      format.xml  { head :ok }
    end
  end
end
