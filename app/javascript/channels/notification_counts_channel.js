
import consumer from "./consumer"

consumer.subscriptions.create("NotificationCountsChannel", {
  connected(e) {
    console.log('Connected to NotificationCountsChannel')
  },

  received(data) {
    this.badge.html(data["count"] == 0 ? "" : data["count"]);
    this.badge.data("count", data["count"]);
  },

  get badge() {
    return $("#notification-count-badge");
  }
});

