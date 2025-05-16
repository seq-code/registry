
// These functions depend upon the Bootstrap application, so they cannot
// currently be shipped as a pack

$(document).on("turbolinks:load", function() {
  $(".modal[data-async]").each(function() {
    var container = $(this);
    container.on("show.bs.modal", function (event) {
      var t = $(event.relatedTarget)
      if (!t.data("loaded"))
        $.get(container.data("async"), function(data) {
          container.find(".modal-body").html(data);
          t.data("loaded", true);
        });
    });
  });
});

function new_toast(title, body, url) {
  var toast = $(
    "<div class=toast role=alert aria-live=assertive aria-atomic=true " +
      "data-autohide=false data-delay=30000></div>"
  );
  toast.append($(
    "<div class=toast-header>" +
      "<strong class=mr-auto>" + title + "</strong>" +
      "<button type=button class='ml-2 mb-1 close' data-dismiss='toast' " +
        "aria-label=Close><span aria-hidden=true>&times;</span>" +
      "</button>" +
    "</div>"
  ));
  var toast_body = $("<div class='toast-body'></div>")
      .append(
        $("<a class='btn btn-sm text-left' href='" + url + "'></a>")
          .append(body)
      );
  toast.append(toast_body);
  $("#toastCont").append(toast);
  toast.toast('show');
}

