# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    # If the user is already signed in and tries to access the sign-in page,
    # redirect them to the stored return location (e.g., page they came from)
    # to support flows where guests are redirected to sign in from a POST.
    def new
      if user_signed_in?
        stored = stored_location_for(:user)
        return redirect_to(stored) if stored
      end

      super
    end

    protected

    def after_sign_in_path_for(resource)
      stored_location_for(resource) || super
    end
  end
end
