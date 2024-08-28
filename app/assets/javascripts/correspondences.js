
// This function depends upon the Bootstrap application, so it cannot
// currently be shipped as a pack

function correspondence_templates() {
  var box = $("#name_correspondence_message,#register_correspondence_message");
  $('[data-behavior="correspondence-templates"] dd').each(function() {
    var template = $(this);
    template.on("click", function() {
      box.html(template.html());
      template.parents(".modal").modal("hide");
    });
  });
}

