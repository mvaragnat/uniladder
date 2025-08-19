# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('GMAIL_USERNAME', nil)
  layout 'mailer'
end
