class Deploy < ActiveRecord::Base

  belongs_to :app, :inverse_of => :deploys

  after_create :resolve_app_errs, :if => :should_resolve_app_errs?
  after_create :store_cached_attributes_on_problems
  after_create :deliver_email

  validates_presence_of :username, :environment

  scope :by_created_at, order("created_at DESC")

  def resolve_app_errs
    app.problems.unresolved.in_env(environment).each {|problem| problem.resolve!}
  end

  def short_revision
    revision.to_s[0,7]
  end

  def should_notify?
    app.should_notify_on_deploy?
  end

  protected

    def should_resolve_app_errs?
      app.resolve_errs_on_deploy?
    end

    def store_cached_attributes_on_problems
      Problem.where(:app_id => app.id).each(&:cache_app_attributes)
    end

    def deliver_email
      if should_notify?
        Mailer.deploy_notification(self).deliver
      end
    end

end

