# frozen_string_literal: true

require 'test_helper'

module Tournament
  class RegistrationTest < ActiveSupport::TestCase
    setup do
      @t = ::Tournament::Tournament.create!(
        name: 'Autumn Open',
        creator: users(:player_one),
        game_system: game_systems(:chess),
        format: 'open'
      )
      @user = users(:player_two)
    end

    test 'valid registration' do
      reg = ::Tournament::Registration.new(tournament: @t, user: @user)
      assert reg.valid?
    end

    test 'uniqueness per tournament and user' do
      ::Tournament::Registration.create!(tournament: @t, user: @user)
      dup = ::Tournament::Registration.new(tournament: @t, user: @user)
      assert_not dup.valid?
      assert dup.errors[:user_id].present?
    end

    test 'valid status values' do
      reg = ::Tournament::Registration.new(tournament: @t, user: @user)

      reg.status = 'pending'
      assert reg.valid?

      reg.status = 'checked_in'
      assert reg.valid?
    end

    test 'invalid status values' do
      reg = ::Tournament::Registration.new(tournament: @t, user: @user)

      reg.status = 'approved'
      assert_not reg.valid?
      assert reg.errors[:status].present?
      assert_includes reg.errors[:status].first, 'is not included in the list'

      reg.status = 'invalid_status'
      assert_not reg.valid?
      assert reg.errors[:status].present?
      assert_includes reg.errors[:status].first, 'is not included in the list'
    end
  end
end
