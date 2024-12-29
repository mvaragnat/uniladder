# frozen_string_literal: true

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'should not save user without username' do
    user = User.new(email: 'test@example.com')
    assert_not user.save, 'Saved the user without a username'
  end

  test 'should not save user without email' do
    user = User.new(username: 'testuser')
    assert_not user.save, 'Saved the user without an email'
  end

  test 'should not save user with invalid email' do
    user = User.new(username: 'testuser', email: 'invalid-email')
    assert_not user.save, 'Saved the user with an invalid email'
  end

  test 'should not save user with duplicate username' do
    User.create!(username: 'testuser', email: 'test1@example.com')
    user = User.new(username: 'testuser', email: 'test2@example.com')
    assert_not user.save, 'Saved the user with a duplicate username'
  end

  test 'should not save user with duplicate email' do
    User.create!(username: 'testuser', email: 'test1@example.com')
    user = User.new(username: 'testuser2', email: 'test1@example.com')
    assert_not user.save, 'Saved the user with a duplicate email'
  end
end
