class DeploysController < ApplicationController
  
  skip_before_filter :verify_authenticity_token, :only => :create
  skip_before_filter :authenticate_user!, :only => :create
  
  def create
    @app = App.find_by_api_key!(params[:api_key])
    if params[:deploy]
      deploy = {
        :username     => params[:deploy][:local_username],
        :environment  => params[:deploy][:rails_env],
        :repository   => params[:deploy][:scm_repository],
        :revision     => params[:deploy][:scm_revision],
      }
    end

    # handle Heroku's HTTP post deployhook format
    deploy ||= {
      :username     => params[:user],
      :environment  => params[:rack_env].try(:downcase) || params[:app],
      :repository   => "git@heroku.com:#{params[:app]}.git",
      :revision     => params[:head],
    }

    @deploy = @app.deploys.create!(deploy)
    render :xml => @deploy
  end

  def index 
    # See AppsController#find_app for the reasoning behind this code. 
    app = App.find(params[:app_id])
    raise(Mongoid::Errors::DocumentNotFound.new(App,app.id)) unless current_user.admin? || current_user.watching?(app)

    @deploys = app.deploys.order_by(:created_at.desc).paginate(:page =>  params[:page], :per_page => 10)
  end
  
end