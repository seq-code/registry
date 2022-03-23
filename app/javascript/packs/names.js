var k = null;
//$(document).ready(function() {
//document.addEventListener("turbolinks:load", function() {
$(document).on("turbolinks:load", function() {
  $input = $('*[data-behavior="autocomplete"][data-autocomplete="name"]')
  var options = {
    url: function(phrase) {
      return "/autocomplete_names.json?q=" + phrase;
    },
    getValue: "name",
  };
  $input.easyAutocomplete(options);
});
