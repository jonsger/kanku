function toggle_element(id) {
  var element = $(id);
  var css_display = element.css("display");
  var style = (css_display == "none") ? "block" : 'none';
  element.css("display", style);
}

