require 'test_helper'

class RegistersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @register = registers(:one)
  end

  test 'should get index' do
    get registers_url
    assert_response :success
  end

  test 'should get new' do
    get new_register_url
    assert_response :success
  end

  test 'should create register' do
    assert_difference('Register.count') do
      post registers_url, params: { register: { accession: @register.accession, publication_id: @register.publication_id, submitted: @register.submitted, user_id: @register.user_id, validated: @register.validated, validated_by: @register.validated_by } }
    end

    assert_redirected_to register_url(Register.last)
  end

  test 'should show register' do
    get register_url(@register)
    assert_response :success
  end

  test 'should get edit' do
    get edit_register_url(@register)
    assert_response :success
  end

  test 'should update register' do
    patch register_url(@register), params: { register: { accession: @register.accession, publication_id: @register.publication_id, submitted: @register.submitted, user_id: @register.user_id, validated: @register.validated, validated_by: @register.validated_by } }
    assert_redirected_to register_url(@register)
  end

  test 'should destroy register' do
    assert_difference('Register.count', -1) do
      delete register_url(@register)
    end

    assert_redirected_to registers_url
  end
end
