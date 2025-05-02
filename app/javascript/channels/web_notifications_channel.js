import consumer from "./consumer"

consumer.subscriptions.create("WebNotificationsChannel", {
  received(data) {
    // TODO
    // - authorize
    // - broadcast
    // - sound
    // - remember to use tags!
    // new Notification(data["title"], { body: data["body"] })
  }
})

