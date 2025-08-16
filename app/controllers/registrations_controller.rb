# frozen_string_literal: true

class RegistrationsController < ApplicationController
  skip_before_action :authenticate_user!

  def new
    redirect_to new_user_registration_path
  end

  def create
    redirect_to new_user_registration_path
  end
end
