# frozen_string_literal: true

class UsersController < ApplicationController
  def search
    @users = User.where('username ILIKE ?', "%#{params[:q]}%")
                 .where.not(id: Current.user.id)
                 .limit(5)

    render json: @users.map { |u| { id: u.id, username: u.username } }
  end
end
