class Wikispecies::OauthController < ApplicationController
  before_action :authenticate_user!

  AUTHORIZE_URL = 'https://meta.wikimedia.org/w/rest.php/oauth2/authorize'
  TOKEN_URL     = 'https://meta.wikimedia.org/w/rest.php/oauth2/access_token'

  def authorize
    state = SecureRandom.hex(16)
    session[:wikispecies_oauth_state] = state

    redirect_to(
      "#{AUTHORIZE_URL}?%s" % {
        response_type: 'code',
        client_id: Rails.application.credentials.dig(:wikimedia, :client_key),
        redirect_uri: wikispecies_oauth_callback_url,
        state: state
      }.to_query,
      allow_other_host: true
    )
  end

  def callback
    if params[:state] != session.delete(:wikispecies_oauth_state)
      redirect_to(
        edit_user_registration_path,
        alert: 'Invalid OAuth state'
      ) and return
    end

    token = exchange_code_for_token(params[:code])
    username = fetch_username(token['access_token'])

    credential = current_user.wikispecies_credential ||
                 current_user.build_wikispecies_credential
    credential.update!(
      access_token: token['access_token'],
      refresh_token: token['refresh_token'],
      expires_at: token['expires_in']&.seconds&.from_now,
      wiki_username: username
    )

    redirect_to(
      dashboard_path,
      notice: "Connected to Wikispecies as #{username}"
    )
  end

  def disconnect
    current_user.wikispecies_credential&.destroy
    redirect_to(
      edit_user_registration_path,
      notice: 'Wikispecies account disconnected'
    )
  end

  private

  def exchange_code_for_token(code)
    uri = URI(TOKEN_URL)
    req = Net::HTTP::Post.new(uri)
    req.set_form_data(
      grant_type: 'authorization_code',
      code: code,
      redirect_uri: wikispecies_oauth_callback_url,
      client_id: Rails.application.credentials.dig(:wikimedia, :client_key),
      client_secret:
        Rails.application.credentials.dig(:wikimedia, :client_secret)
    )
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(req)
    end
    JSON.parse(res.body)
  end

  def fetch_username(access_token)
    uri = URI(
      'https://species.wikimedia.org/w/api.php?%s' % {
        action: 'query',
        meta:   'userinfo',
        format: 'json'
      }.to_query
    )
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{access_token}"
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(req)
    end
    JSON.parse(res.body).dig('query', 'userinfo', 'name')
  end
end
