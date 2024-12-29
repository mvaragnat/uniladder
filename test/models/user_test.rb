# frozen_string_literal: true

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'should not save user without username' do
    user = User.new(email_address: 'test@example.com', password: 'xxx')
    assert_not user.save, 'Saved the user without a username'
  end

  test 'should not save user without email' do
    user = User.new(username: 'testuser')
    assert_not user.save, 'Saved the user without an email'
  end

  test 'should not save user with invalid email' do
    user = User.new(username: 'testuser', email_address: 'invalid-email', password: 'xxx')
    assert_not user.save, 'Saved the user with an invalid email'
  end

  test 'should not save user with duplicate username' do
    users(:player_one)
    user = User.new(username: 'player_one', email_address: 'test2@example.com', password: 'xxx')
    assert_not user.save, 'Saved the user with a duplicate username'
  end

  test 'should not save user with duplicate email' do
    users(:player_one)
    user = User.new(username: 'testuser2', email_address: 'one@example.com', password: 'xxx')
    assert_not user.save, 'Saved the user with a duplicate email'
  end
end
