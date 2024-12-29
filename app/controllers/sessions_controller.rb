# frozen_string_literal: true

class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, with: lambda {
    redirect_to new_session_url, alert: t('auth.sessions.try_later')
  }

  def new; end

  def create
    if (user = User.authenticate_by(email_address: session_params[:email_address], password: session_params[:password]))
      start_new_session_for(user)
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: t('auth.sessions.invalid_credentials')
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end

  def authenticate
    redirect_to new_session_url, alert: t('auth.sessions.try_later') if session_params[:email_address].blank?
  end

  private

  def session_params
    params.permit(:email_address, :password)
  end
end
