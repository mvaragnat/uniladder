# frozen_string_literal: true

class PasswordsController < ApplicationController
  skip_before_action :authenticate_user!

  def new
    redirect_to new_user_password_path
  end

  def edit
    redirect_to edit_user_password_path
  end

  def create
    redirect_to new_user_password_path
  end

  def update
    redirect_to new_user_session_path
  end
end
