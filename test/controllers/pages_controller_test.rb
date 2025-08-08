# frozen_string_literal: true

require 'test_helper'

class PagesControllerTest < ActionDispatch::IntegrationTest
  test 'should get home when not logged in' do
    get root_path
    assert_response :success
    assert_select 'h1', 'Welcome to Uniladder'
  end

  test 'should redirect to dashboard when logged in' do
    user = users(:player_one)
    post session_path, params: { email_address: user.email_address, password: 'password' }

    get root_path
    assert_redirected_to dashboard_path(locale: I18n.locale)
  end

  test 'should get home in French' do
    get root_path(locale: :fr)
    assert_response :success
    assert_select 'h1', 'Bienvenue sur Uniladder'
  end
end
