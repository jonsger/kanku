function get_admin_task_list() {
  var url = uri_base + "/rest/admin/task/list.json";
  axios.get(url).then(update_admin_task_list);
}

function update_admin_task_list(xhr) {
  var data = xhr.data;
  $("#task-list-role-requests").empty();

  if (data.length < 1) {
    $("#task-list-role-requests").append("No requests");
  } else {
    $(data).each(function(idx, request) {

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

  var url = uri_base + "/rest/admin/task/resolve.json";
  var comment = $("textarea#admin-comment-"+req_id).val();

  axios.post(
    url,
    {"req_id":req_id, "decision":decision,"comment":comment}
  ).then(function () {
    get_admin_task_list();
    get_admin_user_list();
  });
}

function get_admin_user_list() {
  var url = uri_base + "/rest/admin/user/list.json";
  console.log(url);
  axios.get(url).then(update_admin_user_list);
}

function update_admin_user_list(xhr) {
  var data = xhr.data;

  $("#user_list").empty();

  if (data.length < 1) {
    $("#user_list").append("Looks like an error - No users found!");
  } else {
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
  axios.get(url).then(update_admin_role_list);
}

function update_admin_role_list(xhr) {
  var data = xhr.data;

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

function delete_user(user_id) {
  var url = uri_base + "/rest/admin/user/" + user_id + ".json";
  console.log(url);
  axios.delete(url).then(get_admin_user_list);
}

$(document).ready(function(){
  get_admin_task_list();
  get_admin_user_list();
  get_admin_role_list();
});
