# frozen_string_literal: true

require 'test_helper'

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test 'redirects to Devise registration page' do
    get new_user_registration_path(locale: I18n.locale)
    assert_response :success
  end
end
