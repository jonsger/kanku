function send_request () {
  console.log("send_request");
  var roles   = new Array();
  var comment = $('textarea#comment').val();
  $('.role_checkbox').each(function(idx, elem) {
    if ($(elem).is(':checked')) { roles.push($(elem).attr('value')); }
  });
  var request = { 'roles' : roles, 'comment' : comment }
  console.log(result);

  var url = uri_base + "/rest/request_roles.json";
  console.log(url);
  var result = $.post(
    url,
    JSON.stringify(request),
    function(response) {
      $("#change_result").removeClass("alert-success");
      $("#change_result").removeClass("alert-warning");
      $("#change_result").addClass("alert-" + response.state);
      $("#change_result").text(response.msg);
      $("#change_result").fadeIn();
      $("#change_result").delay(10000).fadeOut("slow");
    }
  );
}

$(document).ready(function() {
  console.log("ready");
  $('#send_request').on('click', send_request);
});
