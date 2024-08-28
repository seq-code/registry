
// This function depends upon the Bootstrap application, so it cannot
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

