require 'test_helper'

# Chrome reports elements that are no longer in the page (e.g., replaced while
# loading) as a generic error instead of a stale element, which Capybara
# would retry
module StaleElementFromDetachedNode
  private

  def execute(*)
    super
  rescue Selenium::WebDriver::Error::UnknownError => e
    raise unless e.message.include?('does not belong to the document')

    raise Selenium::WebDriver::Error::StaleElementReferenceError, e.message
  end
end
Selenium::WebDriver::Remote::Bridge.prepend(StaleElementFromDetachedNode)

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  # User signed in for every request of the current test (see #sign_in)
  cattr_accessor :signed_in_user

  # Unlike Warden's +login_as+, which only applies to the next request the
  # server receives (possibly a late request from the previous test, such as
  # autocomplete while typing), this applies to every request, regardless of
  # any session cookie left over from the previous test
  Warden::Manager.on_request do |proxy|
    user = ApplicationSystemTestCase.signed_in_user
    if user && proxy.user(:user) != user
      proxy.set_user(user, scope: :user, run_callbacks: false)
    end
  end

  teardown { self.signed_in_user = nil }

  def sign_in(user)
    self.signed_in_user = user
  end
end
