# frozen_string_literal: true

require 'application_system_test_case'

class DashboardTest < ApplicationSystemTestCase
  setup do
    @user = users(:player_one)
    @other_user = users(:player_two)
    @game = game_events(:chess_game)
    login_as(@user)
  end

  test 'displays game history' do
    visit dashboard_path

    within('.bg-white.rounded-lg.shadow') do
      assert_text @game.game_system.localized_name
      assert_text I18n.l(@game.played_at, format: :long)
      assert_text @other_user.username

      participation = @game.game_participations.find_by(user: @user)
      assert_text participation.score.to_s
    end
  end

  test 'displays no games message when user has no games' do
    @user.game_participations.destroy_all

    visit dashboard_path
    assert_text I18n.t('games.no_games')
  end

  test 'shows game history in French' do
    visit dashboard_path(locale: :fr)

    within('.bg-white.rounded-lg.shadow') do
      participation = @game.game_participations.find_by(user: @user)
      assert_text participation.score.to_s
      assert_text I18n.t('games.participants', locale: :fr)
    end
  end

  private

  def login_as(user)
    visit new_user_session_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password'
    click_on I18n.t('auth.login')
  end
end
