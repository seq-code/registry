$(document).on("turbolinks:load", function() {
  $(".copyable:not(:has(.copyer))").each(function() {
    var elem = $(this);
    var cont = elem.text()
    var copied = $(
      '<span class="mr-2 font-weight-lighter"' +
        ' style="display: none;">copied</span>'
    );
    var btn = $(
      '<a class="badge badge-pill badge-primary copyer float-right pl-2"' +
        ' type="button"><i class="fas fa-copy mr-1"> </i></a>'
    );
    if (elem.hasClass("copyable-block")) {
      btn.addClass("mt-3");
    } else {
      btn.addClass("mt-1 ml-2");
      cont = cont.replace(/\s+/gm, " ");
    }
    btn.on("click", function() {
      navigator.clipboard.writeText(cont);
      var i = btn.find("i.fas");
      i.slideUp(200).slideDown(200).delay(2000).slideUp(200).slideDown(200);
      setTimeout(() => {
        i.addClass("fa-check").removeClass("fa-copy");
        copied.slideDown(200);
      }, 200);
      setTimeout(() => {
        copied.slideUp(200);
      }, 2400);
      setTimeout(() => {
        i.addClass("fa-copy").removeClass("fa-check");
      }, 2600);
    });
    btn.prepend(copied);
    elem.append(btn);
  });
});

