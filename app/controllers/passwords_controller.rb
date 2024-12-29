# frozen_string_literal: true

class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[edit update]

  def new; end

  def edit; end

  def create
    if (user = User.find_by(email_address: params[:email_address]))
      PasswordsMailer.with(user: user).reset_password.deliver_later
    end
    redirect_to new_session_path, notice: t('auth.password.reset_sent')
  end

  def update
    if @user.update(password_params)
      redirect_to new_session_path, notice: t('auth.password.reset_success')
    else
      redirect_to edit_password_path(params[:token]), alert: t('auth.password.reset_mismatch')
    end
  end

  private

  def set_user_by_token
    @user = User.find_by!(password_reset_token: params[:token])
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_password_path, alert: t('auth.password.reset_invalid')
  end
end
