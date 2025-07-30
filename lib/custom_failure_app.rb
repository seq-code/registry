class CustomFailureApp < Devise::FailureApp
  def respond
    redirect
  end

  def redirect_url
    # Redirect back to the login page with a flash message
    new_user_session_path
  end
end

