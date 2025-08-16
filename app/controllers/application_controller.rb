# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Must run before Devise's authenticate_user! so we can remember where to go back
  prepend_before_action :store_user_location!, if: :storable_location?
  before_action :authenticate_user!, unless: :devise_controller?
  before_action :set_locale
  before_action :set_current_user
  before_action :configure_permitted_parameters, if: :devise_controller?

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :authenticated?

  private

  def authenticated?
    user_signed_in?
  end

  def set_current_user
    Current.user = current_user
  end

  def set_locale
    I18n.locale = extract_locale || I18n.default_locale
  end

  def extract_locale
    parsed_locale = params[:locale]
    I18n.available_locales.map(&:to_s).include?(parsed_locale) ? parsed_locale : nil
  end

  def default_url_options
    { locale: I18n.locale }
  end

  # Devise: ensure we remember the intended location (referer) for blocked non-GET actions
  def store_user_location!
    store_location_for(:user, request.referer)
  end

  def storable_location?
    !user_signed_in? && request.referer.present? && request.format.html? && !request.xhr? && !request.get?
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:username])
    devise_parameter_sanitizer.permit(:account_update, keys: [:username])
  end
end
