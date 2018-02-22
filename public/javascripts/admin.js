function get_admin_task_list() {
  var url = uri_base + "/rest/admin/task/list.json";
  console.log(url);
  $.get(
    url,
    update_admin_task_list
  );
}

function update_admin_task_list(data) {
  console.log(data);
  $("#task-list-role-requests").empty();

  if (data.length < 1) {
    $("#task-list-role-requests").append("No requests");
  } else {
    $(data).each(function(idx, request) {

      console.log(request.req_id);
      var template = $("#task-list-role-request-template").html();
      Mustache.parse(template);
      var rendered = Mustache.render(
	template,
	request
      );
      $("#task-list-role-requests").append(rendered);

    });
  }
}

function send_role_request(req_id, decision) {
  console.log("this.id: " + req_id);
  console.log("decision: " + decision);
  var url = uri_base + "/rest/admin/task/resolve.json";
  var comment = $("textarea#admin-comment-"+req_id).val();
  console.log("comment:"+comment);
  console.log(url);
  $.post(
    url,
    'args=' + JSON.stringify({"req_id":req_id, "decision":decision,"comment":comment}),
  );
  get_admin_task_list();
}

function get_admin_user_list() {
  var url = uri_base + "/rest/admin/user/list.json";
  console.log(url);
  $.get(
    url,
    update_admin_user_list
  );
}

function update_admin_user_list(data) {
  console.log(data);
  $("#user_list").empty();

  if (data.length < 1) {
    $("#user_list").append("Looks like an error - No users found!");
  } else {
  console.log(data);
    $(data).each(function(idx, user) {
      console.log(user);
      user.roles = user.roles.join(", ");
      var template = $("#user-list-tr-template").html();
      Mustache.parse(template);
      var rendered = Mustache.render(
	template,
	user
      );
      $("#user_list").append(rendered);

    });
  }
}

function get_admin_role_list() {
  var url = uri_base + "/rest/admin/role/list.json";
  console.log(url);
  $.get(
    url,
    update_admin_role_list
  );
}

function update_admin_role_list(data) {
  console.log(data);
  $("#role_list").empty();

  if (data.length < 1) {
    $("#role_list").append("Looks like an error - No roles found!");
  } else {
  console.log(data);
    $(data).each(function(idx, role) {
      console.log(role);
      var template = $("#role-list-tr-template").html();
      Mustache.parse(template);
      var rendered = Mustache.render(
	template,
	role
      );
      $("#role_list").append(rendered);

    });
  }
}

$(document).ready(function(){
  get_admin_task_list();
  get_admin_user_list();
  get_admin_role_list();
});
