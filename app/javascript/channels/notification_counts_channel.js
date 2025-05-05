
import consumer from "./consumer"

consumer.subscriptions.create("NotificationCountsChannel", {
  connected() {
    console.log('Connected to NotificationCountsChannel')
  },

  received(data) {
    console.log('Got data:', data);
    var badge = $("#notification-count-badge");
    badge.html(data["count"] == 0 ? "" : data["count"]);
    badge.data("count", data["count"]);
  }
});

