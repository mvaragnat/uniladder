# frozen_string_literal: true

class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: t('auth.password.reset_subject'), to: user.email_address
  end

  def reset_password
    @user = params[:user]
    @token = @user.generate_token_for(:password_reset)
    mail subject: t('auth.password.reset_subject'), to: @user.email_address
  end
end
