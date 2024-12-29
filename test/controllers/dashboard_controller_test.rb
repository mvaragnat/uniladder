# frozen_string_literal: true

require 'test_helper'

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test 'should redirect to login when not authenticated' do
    get dashboard_path
    assert_redirected_to new_session_path(locale: I18n.locale)
  end

  test 'should show dashboard when authenticated' do
    user = users(:player_one)
    post session_path, params: { email_address: user.email_address, password: 'password' }

    get dashboard_path
    assert_response :success
    assert_select 'h1', "Hello #{user.username}"
  end

  test 'should show dashboard in French when authenticated' do
    user = users(:player_one)
    post session_path, params: { email_address: user.email_address, password: 'password' }

    get dashboard_path(locale: :fr)
    assert_response :success
    assert_select 'h1', "Bonjour #{user.username}"
  end
end
