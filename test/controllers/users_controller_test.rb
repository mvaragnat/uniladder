# frozen_string_literal: true

require 'test_helper'

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:player_one)
    sign_in @user
  end

  test 'should search users' do
    get users_search_path, params: { q: 'play' }
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json.size
    assert_equal users(:player_two).username, json.first['username']
  end

  test 'should not include current user in search results' do
    get users_search_path, params: { q: @user.username }
    assert_response :success

    json = response.parsed_body
    assert_empty json
  end
end
