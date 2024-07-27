const perseus = "https://www.perseus.tufts.edu/hopper/";

function flash_modal(dict_id, target) {
  var modal = $("#" + dict_id);
  const tgt_classes = "text-white bg-info";
  target.addClass(tgt_classes);
  modal.fadeOut(100, function() {
    modal.fadeIn(800, function() { target.removeClass(tgt_classes); });
  });
}

function dictionary_search(dict_id, comp) {
  var select = "[data-behavior='dictionary'][data-id='" + dict_id + "']";
  var modal_body = $("#" + dict_id + " div.modal-body");
  var part = $(select + " #name_etymology_" + comp + "_particle").val();
  var spinner = '<i class="fas fa-spinner fa-spin mr-1"> <i>';
  var definition = $("<div class='definition mb-3'>Looking up " +
    part + "...</div>");
  definition.prepend(spinner);
  var grammar = $("<div class='analyses'>Analysing " + part + "...</div>");
  grammar.prepend(spinner);
  var footer = $("<div></div>");
  footer.append("<hr/>");
  footer.append("Service provided by <a href='" + perseus + "' " +
    "target='_blank'>Perseus Digital Library</a><br/>");
  footer.append("<b>Elem. Lewis</b>: Charlton T. Lewis, An Elementary " +
    "<i>Latin Dictionary</i><br/>");
  footer.append("<b>Lewis & Short</b>: Charlton T. Lewis, Charles Short, " +
    "<i>A Latin Dictionary</i><br/>");

  // Build scaffold
  modal_body.html("");
  modal_body.append(grammar);
  modal_body.append('<hr/>');
  modal_body.append(definition);
  modal_body.append(footer);

  // Launch search
  dictionary_search_grammar(dict_id, comp, modal_body);
}

function dictionary_search_grammar(dict_id, comp, modal_body) {
  var select = "[data-behavior='dictionary'][data-id='" + dict_id + "']";
  var part = $(select + " #name_etymology_" + comp + "_particle").val();

  // Grammatical options (analysis)
  $.ajax({
    url: perseus + "/xmlmorph",
    data: { lang: 'la', lookup: part },
    dataType: 'xml'
  }).done(function(data) {
    var list = $('<ul></ul>');
    var lemmata = [];
    var texts = [];
    var help = $('<p>Click on a lemma (words in parenthesis) to see its ' +
                 'definition, or click "use" to copy the grammar to the ' +
                 'appropriate box in the etymology table</p>');
    help.addClass("text-muted small border-left px-2 mx-2");

    if ($(data).find("analyses analysis").length == 0) {
      help = '';
      list = $('<span class="text-danger ml-4">Term not found</span>');
    } else {
      $(data).find("analyses analysis").each(function() {
        // Parse analysis
        var analysis = $(this);
        var text = "";
        var lemma = analysis.children("lemma").text()
        if (!lemmata.includes(lemma)) lemmata.push(lemma);
        [
          "pos" , "number", "gender", "case", "dialect", "feature"
        ].forEach(function(i) {
          var val = analysis.children(i).text();
          if (!val | val == "sg") return;
          if (i == "case" & val != "gen") return;
          if (i == "pos" & val == "noun") val = "n";
          text = text + " " + val;
          if (i != "dialect" & val != "verb") text = text + ".";
        });
        texts.push(text);
        var item = $("<li></li>");
        var lemma_anchor = $(
          '<a href="#" data-lemma="' + lemma + '">' +
            '<i class="far fa-bookmark small"> </i> ' + lemma +
          '</a>'
        );
        lemma_anchor.on("click", function() {
          dictionary_search_definition(dict_id, comp, modal_body, lemma, 1);
          return false;
        });
        var anchor = $("<span type=button class='badge badge-pill " +
                       "badge-primary ml-2'>use</span>");
        anchor.on("click", function() {
          var target = $(select + " #name_etymology_" + comp + "_grammar");
          target.val(text);
          flash_modal(dict_id, target);
        });

        // Build item and add to list
        item.append("<b>" + analysis.children("form").text() + "</b>");
        item.append(text);
        item.append(" (");
        item.append(lemma_anchor);
        item.append(")");
        item.append(anchor);
        list.append(item);
      });
    }
    modal_body.children('.analyses').html('<h2>Grammatical analyses</h2>');
    modal_body.children(".analyses").append(help);
    modal_body.children(".analyses").append(list);
    if (!lemmata.includes(part)) lemmata.push(part);
    dictionary_search_definition(dict_id, comp, modal_body, lemmata[0], 1);
  }).fail(function() {
    modal_body.children('.analyses')
      .html('<h2>Grammatical analyses</h2>' +
            '<span class="text-danger ml-4">Term not found</span>');
  });
}

function dictionary_search_definition(dict_id, comp, modal_body, part, src) {
  var select = "[data-behavior='dictionary'][data-id='" + dict_id + "']";
  var dicts = ['Perseus:text:1999.04.0059', 'Perseus:text:1999.04.0060'];
  var source_names = ['Lewis & Short', 'Elem. Lewis'];

  // Report process
  var spinner = '<i class="fas fa-spinner fa-spin mr-1 ml-2"> <i>';
  var cont = modal_body.children('.definition');
  cont.append(spinner);
  cont.append("Looking up " + part + "...");
  var bold = "font-weight-bold";
  modal_body.find('.analyses a[data-lemma]').removeClass(bold);
  modal_body.find('.analyses a[data-lemma] i').removeClass('fas');
  modal_body.find('.analyses a[data-lemma] i').removeClass('far');
  modal_body.find('.analyses a[data-lemma="' + part + '"]').addClass(bold);
  modal_body.find('.analyses a[data-lemma="' + part + '"]  i').addClass('fas');
  modal_body.find('.analyses a[data-lemma!="' + part + '"]  i').addClass('far');
  var title = $('<h2 class="input-group">Definition in</h2>');
  var title_src = $(
    '<select class="custom-select ml-2" id="dictionary-title-src"></select>'
  );
  for (var i = 0; i < dicts.length; i++) {
    var title_opt = $(
      '<option value="' + i + '">' + source_names[i] + '</option>'
    );
    if (i == src) title_opt.attr("selected", true);
    title_src.append(title_opt);
  }
  title_src.on("change", function() {
    var new_src = $(this).prop("selectedIndex");
    dictionary_search_definition(dict_id, comp, modal_body, part, new_src)
  });
  title.append(title_src);
  title.append(
    '<div class="input-group-append">' +
      '<label for="dictionary-title-src" class="input-group-text">' +
      '<i class="fas fa-exchange-alt"> </i></label></div>'
  );
  var help = $('<p>Click on "use" to copy the definition to the appropriate ' +
               'box in the etymology table, or see the full formatted ' +
               'definition for the term below in the grey box</p>');
  help.addClass("text-muted small border-left px-2 mx-2");

  // Definition
  $.ajax({
    url: perseus + "/loadquery",
    data: { doc: dicts[src] + ':entry=' + part }
  }).done(function(data) {
    // Fix result for embedding
    var result = $(data);
    result.find("a").each(function() {
      var href = $(this).attr("href");
      $(this).attr("href", perseus + href);
    });

    // Parse definitions
    var cont = modal_body.children('.definition');
    cont.html(title);
    cont.append(help);
    var list = $('<ul class="mb-3"></ul>');
    result.find("div.lex_sense > i").each(function() {
      var description = $(this).text();
      if (/[0-9]|^([a-z ]*\.)*$/i.test(description)) return;
      var item = $("<li></li>");
      var anchor = $("<span type=button class='badge badge-pill " +
                     "badge-primary ml-2'>use</span>");
      anchor.on("click", function() {
        var target = $(select + " #name_etymology_" + comp + "_description");
        target.val(description);
        flash_modal(dict_id, target);
      });
      item.append(description);
      item.append(anchor);
      list.append(item);
    });
    cont.append(list);

    // Show raw definition
    var def = $(
      '<div class="raw-entry mx-2 p-2 border bg-light mb-2"></div>'
    );
    def.append(result);
    cont.append(def);
  }).fail(function() {
    var cont = modal_body.children('.definition')
    cont.html(title);
    cont.append('<span class="text-danger ml-4">Term not found</span>');
  });
}

function dictionary_search_button(dict_id, comp) {
  var select = "[data-behavior='dictionary'][data-id='" + dict_id + "']";
  var td = $(select + " #name_etymology_" + comp + "_dict");
  td.html('');
  var latin = [
    "L", "L.", "Latin", "N.L.", "NL", "NL.", "Neolatin", "Neo Latin",
    "Neo-Latin",
    // The dictionary includes Greek entries
    "Greek", "Gr.",
    // We might as well try if the language is blank
    ""
  ];
  var lang = $(select + " #name_etymology_" + comp + "_lang").val();
  if (!latin.includes(lang)) return;

  if (comp == "xx") {
    var part_id = select + " #name_etymology_xx_particle";
    $(part_id).val($(part_id).text());
  }
  var part = $(select + " #name_etymology_" + comp + "_particle").val();
  if (!part) return;

  var button = $('<span type=button data-toggle=modal' +
    ' data-target="#' + dict_id + '" class="btn btn-sm btn-info">' +
    '<i class="fas fa-book"> </i></span>');
  button.on("click", function() { dictionary_search(dict_id, comp); })
  td.html(button);
}

$(document).on("turbolinks:load", function() {
  const components = ["p1", "p2", "p3", "p4", "p5", "xx"];
  const fields     = ["lang", "particle"];
  $("[data-behavior='dictionary']").each(function() {
    console.log('Initializing Dictionary Lookup');
    var dict_id = $(this).data("id");
    var select  = "[data-behavior='dictionary'][data-id='" + dict_id + "']";
    components.forEach(function(comp_i) {
      fields.forEach(function(field_i) {
        var id = "name_etymology_" + comp_i + "_" + field_i;
        $(select + " #" + id).on("change", function() {
          dictionary_search_button(dict_id, comp_i);
        });
      });
      dictionary_search_button(dict_id, comp_i);
    });
  });
});

