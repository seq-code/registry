
$(document).on("turbolinks:load", function() {
  var eac_options = {
    url: function(phrase) {
      var data = $($(event)[0]["srcElement"]).data();
      var what = data["autocomplete"];
      var path = ROOT_PATH + what + "/autocomplete.json?q=" + phrase;
      for(let i of ["rank"]) {
        if(data[i]) { path = path + "&" + i + "=" + data[i] ; }
      }
      return path;
    },
    getValue: "value",
    template: {
      type: "custom",
      method: function(value, item) { return item.display }
    }
  };
  var input = $('*[data-behavior="autocomplete"][data-autocomplete]');
  input.easyAutocomplete(eac_options);
  // $('#search-bar').easyAutocomplete(eac_options);
});

