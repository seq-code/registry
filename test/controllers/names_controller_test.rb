require 'test_helper'

class NamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @name = names(:unregistered)
  end

end
