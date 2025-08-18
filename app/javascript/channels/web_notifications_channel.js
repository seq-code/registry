import consumer from "./consumer";

const wn_struct = {
  connected() {
    console.log('Connected to WebNotificationChannel');
  },

  received(data) {
    switch (data["kind"]) {
      case "web_notification":
        this.web_notification(data);
        break;
      case "notification_count":
        this.notification_count(data);
        break;
    }
  },

  // Web Notifications (individual event)
  web_notification(data) {
    if (Notification.permission === "granted") {
      this.browser_notification(data);
    }
    this.toast_notification(data);

    // Sound (only if it is allowed)
    if (new AudioContext().state == "running") {
      var bell = ROOT_PATH + "assets/audios/notification.mp3";
      var notification_sound = new Audio(bell);
      notification_sound.play();
    }
  },

  browser_notification(data) {
    var n = new Notification('SeqCode Registry', {
      body: data["title"],
      tag: data["tag"],
      icon: ROOT_PATH + "assets/logo.svg"
    });
    n.addEventListener("click", function(e) {
      window.parent.parent.focus();
      e.currentTarget.close();
    });
  },

  toast_notification(data) {
    new_toast("", data["title"], ROOT_PATH + "alerts/" + data["alert"]);
  },

  // Notification Count (aggregated)
  notification_count(data) {
    var badge = $("#notification-count-badge");
    badge.html(data["count"] == 0 ? "" : data["count"]);
    badge.data("count", data["count"]);
  }
};

consumer.subscriptions.create("WebNotificationsChannel", wn_struct);

$(document).on("turbolinks:load", function() {
  if (Notification.permission === "default") {
    var msg = $("#notification-permission");
    if (msg.length) {
      var btn = $("#notification-permission button");
      btn.on("click", function() {
        Notification.requestPermission().then(function(permission) {
          if (permission === 'granted') msg.slideUp();
        });
      });
      msg.slideDown();
    }
  }
});

