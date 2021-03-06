require 'spec_helper'

describe Mailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  context "Err Notification" do
    let(:notice)  { Fabricate(:notice, :message => "class < ActionController::Base") }
    let!(:user)   { Fabricate(:admin) }

    before do
      notice.backtrace.lines.last.update_attributes(:file => "[PROJECT_ROOT]/path/to/file.js")
      notice.app.update_attributes(
        :asset_host => "http://example.com",
        :notify_all_users => true
      )
      notice.problem.update_attributes :notices_count => 3

      @email = Mailer.err_notification(notice).deliver
    end

    it "should send the email" do
      expect(ActionMailer::Base.deliveries.size).to eq 1
    end

    it "should html-escape the notice's message for the html part" do
      expect(@email).to have_body_text("class &lt; ActionController::Base")
    end

    it "should have inline css" do
      expect(@email).to have_body_text('<p class="backtrace" style="')
    end

    it "should have links to source files" do
      expect(@email).to have_body_text('<a href="http://example.com/path/to/file.js" target="_blank">path/to/file.js')
    end

    it "should have the error count in the subject" do
      expect(@email.subject).to match( /^\(3\) / )
    end

    context 'with a very long message' do
      let(:notice)  { Fabricate(:notice, :message => 6.times.collect{|a| "0123456789" }.join('')) }
      it "should truncate the long message" do
        expect(@email.subject).to match( / \d{47}\.{3}$/ )
      end
    end
  end

  context "Comment Notification" do
    let!(:notice) { Fabricate(:notice) }
    let!(:comment) { Fabricate.build(:comment, :err => notice.problem) }
    let!(:watcher) { Fabricate(:watcher, :app => comment.app) }
    let(:recipients) { ['recipient@example.com', 'another@example.com']}

    before do
      comment.stub(:notification_recipients).and_return(recipients)
      Fabricate(:notice, :err => notice.err)
      @email = Mailer.comment_notification(comment).deliver
    end

    it "should send the email" do
      expect(ActionMailer::Base.deliveries.size).to eq 1
    end

    it "should be sent to comment notification recipients" do
      expect(@email.to).to eq recipients
    end

    it "should have the notices count in the body" do
      expect(@email).to have_body_text("This err has occurred 2 times")
    end

    it "should have the comment body" do
      expect(@email).to have_body_text(comment.body)
    end
  end

  context "Deploy Notification" do
    let!(:app) { Fabricate(:app_with_watcher) }
    let!(:first_deploy) { Fabricate(:deploy, app: app) }
    let!(:second_deploy) { Fabricate(:deploy, app: app) }

    before do
      second_deploy.reload
      @email = Mailer.deploy_notification(second_deploy).deliver
    end

    it "should send the email" do
      expect(ActionMailer::Base.deliveries.size).to eq 1
    end

    it "should have the changes" do
      expect(@email).to have_body_text("CHANGES:")
    end
  end
end
