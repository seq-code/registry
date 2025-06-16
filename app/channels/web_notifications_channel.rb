class WebNotificationsChannel < ApplicationCable::Channel
  def subscribed
    # Open streaming
    stream_for current_user

    # Proactively send count on subscription
    transmit({
      kind: 'notification_count',
      count: current_user.unseen_notifications.count
    })
  end
end
