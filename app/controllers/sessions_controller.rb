# frozen_string_literal: true

class SessionsController < ApplicationController
  # Legacy controller no longer used; keep minimal redirect for old routes if any remain
  skip_before_action :authenticate_user!

  def new
    redirect_to new_user_session_path
  end

  def create
    redirect_to new_user_session_path
  end

  def destroy
    redirect_to destroy_user_session_path, allow_other_host: true
  end
end
