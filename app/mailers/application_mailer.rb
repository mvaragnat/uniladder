# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('GMAIL_FROM_EMAIL', 'from@example.com')
  layout 'mailer'
end
