# frozen_string_literal: true

require 'test_helper'

class ContactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:player_one)
    sign_in @user
  end
  
  test 'should get new' do
    get new_contact_path(locale: I18n.default_locale)
    assert_response :success
  end

  test 'should post create and redirect with notice' do
    assert_emails 1 do
      post contacts_path(locale: I18n.default_locale), params: { contact: { subject: 'Hello', content: 'World' } }
    end
    assert_redirected_to root_path(locale: I18n.default_locale)
    assert_not_nil flash[:notice]
  end

  test 'invalid contact shows errors' do
    post contacts_path(locale: I18n.default_locale), params: { contact: { subject: '', content: '' } }
    assert_response :unprocessable_entity
    assert_not_nil flash[:alert]
  end
end
