# frozen_string_literal: true

class UsersController < ApplicationController
  def search
    @users = User.where('username ILIKE ?', "%#{params[:q]}%")
    @users = @users.where.not(id: Current.user.id) if Current.user

    if params[:tournament_id].present?
      ids = Tournament::Registration.where(tournament_id: params[:tournament_id]).pluck(:user_id)
      @users = @users.where(id: ids)
    end

    @users = @users.limit(10)

    render json: @users.map { |u| { id: u.id, username: u.username } }
  end
end
