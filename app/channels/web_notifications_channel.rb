class WebNotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_from current_user
  end
end
