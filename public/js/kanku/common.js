function toggle_element(id) {
  var element = $(id);
  var css_display = element.css("display");
  var style = (css_display == "none") ? "block" : 'none';
  element.css("display", style);
}

function show_messagebox(state, msg) {
  var elem = $("#messagebox");
  elem.removeClass("alert-success");
  elem.removeClass("alert-warning");
  elem.removeClass("alert-danger");
  elem.addClass("alert-" + state);
  elem.text(msg);
  elem.show
  var intervalID = setTimeout(function() { elem.hide(); }, 10000);
}
