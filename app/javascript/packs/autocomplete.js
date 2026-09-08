
$(document).on("turbolinks:load", function() {
  var eac_options = {
    url: function(phrase) {
      var data = $($(event)[0]["srcElement"]).data();
      var what = data["autocomplete"];
      var url = new URL(what + "/autocomplete.json", ROOT_PATH);
      url.searchParams.set("q", phrase);
      if(data["rank"]) { url.searchParams.set("rank", data["rank"]); }
      if(data["minimumRank"]) {
        url.searchParams.set("minimum_rank", data["minimumRank"]);
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
