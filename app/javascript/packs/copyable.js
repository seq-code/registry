$(document).on("turbolinks:load", function() {
  $(".copyable:not(:has(.copyer))").each(function() {
    var elem = $(this);
    var cont = elem.text().replace(/\s+/gm, " ");
    var copied = $(
      '<span style="display: none;" class="small">' +
      'Copied to the clipboard</span>'
    );
    var btn = $(
      '<a class="badge badge-pill badge-primary mx-2 copyer" type="button">' +
      '<i class="fas fa-copy mr-1"> </i> Copy</a>'
    );
    btn.on("click", function() {
      navigator.clipboard.writeText(cont);
      copied.fadeIn(200).delay(800).fadeOut(800);
    });
    elem.append(btn);
    elem.append(copied);
  });
});

