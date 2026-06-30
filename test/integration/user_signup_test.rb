# frozen_string_literal: true

require 'test_helper'

class UserSignupTest < ActionDispatch::IntegrationTest
  test 'signs up and confirms a user' do # rubocop:disable Metrics/BlockLength
    user_count = User.count
    email_count = ActionMailer::Base.deliveries.size

    post user_registration_url, params: {
      user: {
        email: 'new-user@example.com',
        username: 'new_user',
        password: 'password123',
        password_confirmation: 'password123',
        family: 'User',
        given: 'New',
        affiliation: 'Primary institution',
        # rubocop:disable Naming/VariableNumber
        affiliation_2: 'Secondary institution',
        # rubocop:enable Naming/VariableNumber
        opt_regular_email: false,
        opt_message_email: false,
        opt_notification: false
      }
    }

    assert_equal user_count + 1, User.count
    assert_equal email_count + 1, ActionMailer::Base.deliveries.size

    user = User.find_by!(email: 'new-user@example.com')
    assert_equal 'new_user', user.username
    assert_equal 'User', user.family
    assert_equal 'New', user.given
    assert_equal 'Primary institution', user.affiliation
    assert_equal 'Secondary institution', user.affiliation_2
    assert_not user.opt_regular_email
    assert_not user.opt_message_email
    assert_not user.opt_notification
    assert_not user.confirmed?
    assert_response :redirect

    confirmation_link = Nokogiri::HTML(
      ActionMailer::Base.deliveries.last.body.to_s
    ).at_css('a[href*="/users/confirmation?confirmation_token="]')

    assert confirmation_link, 'confirmation email has no confirmation link'

    get confirmation_link['href']

    assert user.reload.confirmed?
    assert_response :redirect
  end # rubocop:enable Metrics/BlockLength
end
