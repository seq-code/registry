require 'test_helper'

class JournalsControllerTest < ActionDispatch::IntegrationTest
  test 'show resolves a journal name with an embedded period, untruncated' do
    get('/journals/' + ERB::Util.url_encode('Cryptogamie. Algologie'))
    assert_response :success
    assert_equal 'Cryptogamie. Algologie', @request.params[:journal]
    assert_nil @request.params[:format]
  end

  test 'show resolves a journal name with a trailing period' do
    get('/journals/' + ERB::Util.url_encode('Can. J. Fish. Aquat. Sci. Bull.'))
    assert_response :success
    assert_equal 'Can. J. Fish. Aquat. Sci. Bull.', @request.params[:journal]
  end

  test 'show still honors an explicit .json format on a plain journal name' do
    get('/journals/' + ERB::Util.url_encode('Nature') + '.json')
    assert_response :success
    assert_equal 'Nature', @request.params[:journal]
    assert_equal 'json', @request.params[:format]
  end

  test 'index still honors an explicit .json format' do
    get('/journals.json')
    assert_response :success
    assert_equal 'json', @request.params[:format]
  end
end
