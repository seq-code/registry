
$(document).on("turbolinks:load", function() {
  var eac_options = {
    adjustWidth: false,
    url: function(phrase) {
      var data = $($(event)[0]["srcElement"]).data();
      var what = data["autocomplete"];
      var url = new URL(what + "/autocomplete.json", ROOT_PATH);
      url.searchParams.set("q", phrase);
      if(data["ranks"] !== undefined) {
        url.searchParams.set("ranks", data["ranks"].join(","));
      }
      return url.toString();
    },
    getValue: "value",
    template: {
      type: "custom",
      method: function(value, item) { return item.display }
    }
  };
  var input = $('*[data-behavior="autocomplete"][data-autocomplete]');
  input.easyAutocomplete(eac_options);
  console.log('Autocomplete initialized');
});
