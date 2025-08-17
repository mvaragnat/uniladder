# frozen_string_literal: true

require 'application_system_test_case'

class LoginTest < ApplicationSystemTestCase
  test 'user can sign in' do
    visit new_user_session_path

    fill_in User.human_attribute_name(:email), with: users(:player_one).email
    fill_in User.human_attribute_name(:password), with: 'password'
    click_button I18n.t('auth.login')

    assert_current_path dashboard_path(locale: I18n.locale)
    assert page.has_content?(I18n.t('auth.logout'))
  end
end
