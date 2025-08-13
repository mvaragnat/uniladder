# frozen_string_literal: true

require 'application_system_test_case'

class TournamentAdminStrategiesTest < ApplicationSystemTestCase
  setup do
    @creator = users(:player_one)
    @system = game_systems(:chess)
  end

  def login_as(user)
    visit new_session_path
    fill_in 'email_address', with: user.email_address
    fill_in 'password', with: 'password'
    click_on I18n.t('auth.login')
  end

  test 'elimination admin shows tie-breaks only, no pairing dropdown' do
    login_as(@creator)
    visit new_tournament_path
    fill_in 'tournament[name]', with: 'Elim T'
    fill_in 'tournament[description]', with: 'X'
    select @system.name, from: 'tournament[game_system_id]'
    select 'elimination', from: 'tournament[format]'
    click_on I18n.t('tournaments.create_new', default: 'Create new tournament'), match: :first

    # Redirected to show
    assert_text 'Elim T'

    # Go to Admin
    click_on I18n.t('tournaments.show.tabs.admin', default: 'Admin')

    # No pairing selector
    assert_no_selector "select[name='tournament[pairing_strategy_key]']"

    # Tie-breaks present
    assert_selector "select[name='tournament[tiebreak1_strategy_key]']"
    assert_selector "select[name='tournament[tiebreak2_strategy_key]']"
  end

  test 'open admin shows tie-breaks only, no pairing dropdown' do
    login_as(@creator)
    visit new_tournament_path
    fill_in 'tournament[name]', with: 'Open T'
    fill_in 'tournament[description]', with: 'Y'
    select @system.name, from: 'tournament[game_system_id]'
    select 'open', from: 'tournament[format]'
    click_on I18n.t('tournaments.create_new', default: 'Create new tournament'), match: :first

    assert_text 'Open T'

    click_on I18n.t('tournaments.show.tabs.admin', default: 'Admin')

    assert_no_selector "select[name='tournament[pairing_strategy_key]']"
    assert_selector "select[name='tournament[tiebreak1_strategy_key]']"
    assert_selector "select[name='tournament[tiebreak2_strategy_key]']"
  end

  test 'swiss admin shows pairing and persists with explanation update' do
    login_as(@creator)
    visit new_tournament_path
    fill_in 'tournament[name]', with: 'Swiss T'
    fill_in 'tournament[description]', with: 'Z'
    select @system.name, from: 'tournament[game_system_id]'
    select 'swiss', from: 'tournament[format]'
    click_on I18n.t('tournaments.create_new', default: 'Create new tournament'), match: :first

    assert_text 'Swiss T'

    click_on I18n.t('tournaments.show.tabs.admin', default: 'Admin')

    # Pairing present
    assert_selector "select[name='tournament[pairing_strategy_key]']"

    # Change tie-break #1 and expect a success flash and explanation change
    within('div[data-controller="strategy"]') do
      select 'None', from: 'tournament[tiebreak1_strategy_key]'
    end

    assert_selector '.flash.flash--notice', text: I18n.t('tournaments.show.strategies.saved', default: 'Settings saved')
    assert_text I18n.t('tournaments.show.strategies.explanations.tiebreak.none', default: 'No tie-break applied.')
  end
end
