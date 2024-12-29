# frozen_string_literal: true

require 'test_helper'

class PagesControllerTest < ActionDispatch::IntegrationTest
  test 'should get home when not logged in' do
    get root_path
    assert_response :success
    assert_select 'h1', 'Welcome to Uniladder'
  end

  test 'should get home when logged in' do
    user = users(:player_one)
    post session_path, params: { email_address: user.email_address, password: 'password' }
    
    get root_path
    assert_response :success
    assert_select 'h1', 'Welcome to Uniladder'
  end
end
