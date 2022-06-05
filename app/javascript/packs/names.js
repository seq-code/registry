$(document).on("turbolinks:load", function() {
  $input = $('*[data-behavior="autocomplete"][data-autocomplete="name"]')
  var options = {
    url: function(phrase) {
      var path = ROOT_PATH + "autocomplete_names.json?q=" + phrase;
      var data = $($(event)[0]["srcElement"]).data();
      for(let i of ["rank"]) {
        if(data[i]) { path = path + "&" + i + "=" + data[i] ; }
      }
      return path;
    },
    getValue: "name",
  };
  $input.easyAutocomplete(options);
});

