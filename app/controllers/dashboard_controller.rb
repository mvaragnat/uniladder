# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :authenticate!

  def show
    @user = Current.user
  end

  private

  def authenticate!
    redirect_to new_session_path unless Current.user
  end
end
