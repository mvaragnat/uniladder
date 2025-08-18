# frozen_string_literal: true

class ContactMailer < ApplicationMailer
  def notify(subject, content)
    @content = content

    mail(
      to: ENV.fetch('CONTACT_TO_EMAIL', 'owner@example.com'),
      from: ENV.fetch('GMAIL_FROM_EMAIL', 'from@example.com'),
      subject: subject
    )
  end
end
