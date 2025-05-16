import consumer from "./consumer";

const wn_struct = {
  connected() {
    console.log('Connected to WebNotificationChannel');
  },

  received(data) {
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
  }
};

if (Notification.permission === "granted") {
  consumer.subscriptions.create("WebNotificationsChannel", wn_struct);
}

$(document).on("turbolinks:load", function() {
  if (Notification.permission === "default") {
    var msg = $("#notification-permission");
    if (msg.length) {
      var btn = $("#notification-permission button");
      btn.on("click", function() {
        Notification.requestPermission().then(function(permission) {
          if (permission === 'granted') {
            msg.slideUp();
            consumer.subscriptions.create("WebNotificationsChannel", wn_struct);
          }
        });
      });
      msg.slideDown();
    }
  }
});

