require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should get sign up form" do
    get sign_up_path
    assert_response :success
    assert_select "h1", "Sign Up"
  end

  test "should create new user and log in" do
    assert_difference "User.count" do
      post sign_up_path, params: {
        user: {
          username: "newuser",
          email_address: "new@example.com",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    assert_redirected_to dashboard_path
    assert_equal "Welcome to Uniladder!", flash[:notice]
    
    # Verify we're logged in
    get dashboard_path
    assert_response :success
    assert_select "h1", "Hello newuser"
  end

  test "should show errors on invalid submission" do
    post sign_up_path, params: {
      user: {
        username: "",
        email_address: "invalid",
        password: "password",
        password_confirmation: "different"
      }
    }

    assert_response :unprocessable_entity
    assert_select "div.bg-red-50" # Error messages container
  end
end 