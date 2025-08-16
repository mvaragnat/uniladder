# frozen_string_literal: true

require 'application_system_test_case'

class AuthPagesTest < ApplicationSystemTestCase
  test 'login page renders and can sign in' do
    visit new_user_session_path
    assert_text I18n.t('auth.login')

    fill_in User.human_attribute_name(:email), with: users(:player_one).email
    fill_in User.human_attribute_name(:password), with: 'password'
    click_on I18n.t('auth.login')

    assert_current_path root_path # may redirect to stored location; root is fine
  end

  test 'signup page renders and can register' do
    visit new_user_registration_path
    assert_text I18n.t('auth.signup')

    email = "u#{SecureRandom.hex(4)}@example.com"
    fill_in User.human_attribute_name(:username), with: "new_user_#{SecureRandom.hex(2)}"
    fill_in User.human_attribute_name(:email), with: email
    fill_in User.human_attribute_name(:password), with: 'password'
    fill_in User.human_attribute_name(:password_confirmation), with: 'password'
    click_on I18n.t('auth.signup')

    assert_current_path root_path
  end
end
