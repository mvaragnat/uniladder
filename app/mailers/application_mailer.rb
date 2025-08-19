# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('GMAIL_FROM_EMAIL', nil)
  layout 'mailer'
end
