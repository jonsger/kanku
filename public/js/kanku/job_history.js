var header_template                 = $("#job_history_header").html();
var job_result_template             = $("#job_result_panel").html();
var subtask_result_template         = $("#subtask_result_panel").html();

var subtask_result_success_template = $("#subtask_result_success").html();
var subtask_result_failed_template  = $("#subtask_result_failed").html();
var job_result_failed_template      = $("#job_result_failed").html();
var job_result_panel_info           = $("#job_result_panel_info").html();
var single_job_comment              = $("#single_job_comment").html();

Mustache.parse(header_template);
Mustache.parse(job_result_template);
Mustache.parse(subtask_result_success_template);
Mustache.parse(subtask_result_failed_template);
Mustache.parse(job_result_failed_template);
Mustache.parse(job_result_panel_info);
Mustache.parse(single_job_comment);

var alert_map =[];
alert_map['succeed'] = 'success';
alert_map['running'] = 'info';
alert_map['failed']  = 'danger';
alert_map['skipped']  = 'warning';
alert_map['dispatching']  = 'warning';

function save_job_comment (job_id) {

  var comment = $("#new_comment_text_"+job_id).val();
  var comment =JSON.stringify(
    {
      "job_id"   : job_id,
      "message"  : comment
    }
  );
  var url = uri_base + "/rest/job/comment/" + job_id + ".json";
  axios.post(url, comment).then(function () { update_comments(job_id); });
}

function delete_job_comment (comment_id, job_id) {
  var url = uri_base + "/rest/job/comment/" + comment_id + ".json";
  axios.delete(url).then(update_comments(job_id));
}

function start_edit_job_comment (comment_id, job_id) {

  var org_comment = $("#job_comment_panel_body_"+comment_id).text();

  $("#job_comment_panel_body_"+comment_id).empty();

  $("#job_comment_panel_body_"+comment_id).append(
    "<textarea id='job_comment_edit_textarea_"+comment_id+"' style='width:100%;'>"
     + $.trim(org_comment) +
    "</textarea>" +
    "<button "
     + "class='btn btn-primary' "
     + "style='margin-top:2px;' "
     + "onclick='finish_edit_job_comment("+comment_id+","+job_id+")'>"+
     "save" +
     "</button>"
  );
}

function finish_edit_job_comment (comment_id, job_id) {
  var url  = uri_base + "/rest/job/comment/" + comment_id + ".json";
  var data = {message : $("#job_comment_edit_textarea_"+comment_id).val()};
  axios.put(url, data).then(update_comments(job_id));
}

function update_comments (job_id) {

  $("#job_comment_body_"+job_id).empty();

  var url = uri_base + "/rest/job/comments/"+job_id+".json";  

  axios.get(url).then(
    function (xhr) {
      var data = xhr.data;
      var comments_as_html = "";

      $.each(data.comments, function (idx, comment) {

        var show_mod = 0;

        if ( user_id == comment.user.id ) {
          show_mod = 1;
        }

        var rendered = Mustache.render(
          single_job_comment,
          {
            username      : comment.user.username,
            name          : comment.user.name,
            comment       : comment.comment,
            show_mod      : show_mod,
            comment_id    : comment.id,
            job_id        : job_id,
          }
        );
        comments_as_html += rendered;
      });
      comments_as_html += "<hr/>";
      $("#job_comment_body_"+job_id).empty();
      $("#job_comment_body_"+job_id).append(comments_as_html);
      $("#new_comment_text_"+job_id).val('');
    }
  );
}

function update_job_history (xhr) {

  var data = xhr.data;
  $("#job_history").empty();

  var rendered = Mustache.render(
                  header_template,
                  {
                    id            : "ID",
                    name          : "Name",
                    start_time    : "Start time",
                    duration      : "Duration",
                    state_class   : "default"
                  }
  );

  $("#job_history").append(rendered);

  $.each(
    data.jobs,
    function (job) {
      var alert_map =[];
      alert_map['succeed']  = 'success';
      alert_map['running']  = 'info';
      alert_map['failed']   = 'danger';
      alert_map['skipped']  = 'warning';
      alert_map['dispatching']  = 'warning';

      var duration_min = 0;
      var duration_sec = 0;
      var start_time   = 0;

      if ( this.start_time ) {
        start_time = new Date(1000 * this.start_time);
        var due = Math.floor(Date.now() / 1000);

        if ( this.end_time ) { due = this.end_time; }

        var duration = due - this.start_time;
        duration_min = Math.floor( duration / 60 );
        duration_sec = duration % 60;
      }
      // workerinfo : host:pid:queue
      var winfo = ('Not started',0,'Not started');
      if ( this.workerinfo ) {
         winfo = this.workerinfo.split(':');
      }
      var comments_icon    = "";
      var comments_as_html = "";
      var job_id           = this.id;
      if ( this.comments ) {
        if ( this.comments.length > 0 ) {
          comments_icon = 'fas';
          $.each(this.comments, function(idx, comment) {

            var show_mod = 0;

            if ( user_id == comment.user.id ) {
              show_mod = 1;
            }

            var rendered = Mustache.render(
                  single_job_comment,
                  {
                    username      : comment.user.username,
                    name          : comment.user.name,
                    comment       : comment.comment,
                    show_mod      : show_mod,
                    comment_id    : comment.id,
                    job_id        : job_id,
                  }
            );
            comments_as_html += rendered;
          });
          comments_as_html += "<hr/>";
        } else {
          comments_icon = 'far';
        }
      }

      var rendered = Mustache.render(
                      job_result_template,
                      {
                        id            : this.id,
                        name          : this.name,
                        start_time    : ( start_time ) ? start_time.toLocaleString() : "not started yet",
                        duration_min  : duration_min,
                        duration_sec  : duration_sec,
                        state_class   : alert_map[this.state],
                        workerhost    : winfo[0],
                        comments_icon : comments_icon,
                        comments_as_html : comments_as_html,
                        pwrand           : this.pwrand,
                      }
      );
      $("#job_history").append(rendered);
      $("#modal_window_comment_"+this.id).on('hidden.bs.modal', function(){
        get_job_history();
      });
      $("#jh_ph_link_"+this.id).click(function (ev) {
        var ev_id           = $(ev.currentTarget).attr('id');
        var job_history_id  = ev_id.replace('jh_ph_link_','');
        var element = $('#jbody_'+job_history_id);
        element.empty();
        var url = uri_base + "/rest/job/" + job_history_id + ".json";
        axios.get(url).then(update_job_result_panel_body);
	toggle_element('#jbody_'+job_history_id);
      });
    }
  );
}

function update_job_result_panel_body (xhr) {
  var data   = xhr.data;
  var job_id = data.id;
  var body   = $("#jbody_"+job_id);

  if ( data.result ) {
    var job_result = JSON.parse(data.result);

    if (job_result.error_message) {
      var rendered = Mustache.render(
	job_result_failed_template,
	{
	  error_message   : job_result.error_message.replace(/\n/,"\n")
	}
      );
      body.append(rendered);
    }
  }

  var info_box = Mustache.render(
                  job_result_panel_info,
                  {
                    'id'          : data.id,
                    'workerhost'  : data.workerhost,
                    'workerpid'   : data.workerpid,
                    'workerqueue' : data.workerqueue,
                  }
  );

  body.append(info_box);

  $.each(
    data.subtasks,
    function() {

      var result_rendered;

      var rendered = Mustache.render(
                  subtask_result_template,
                  {
                    id              : this.id,
                    name            : this.name,
                    state_class     : alert_map[this.state],
                  }
      );

      if ( this.state == "failed" ) {

        result_rendered = Mustache.render(
            subtask_result_failed_template,
            {
              error_message   : this.result.error_message.replace(/\n/,"\n")
            }
        );

      } else {
        var result = {};
        if ( this.result ) {
          result = {
            result_prepare  : this.result.prepare.message,
            result_execute  : this.result.execute.message,
            result_finalize : this.result.finalize.message
          };
        }
        result_rendered = Mustache.render(
            subtask_result_success_template,
            result
        );
      }

      // stbody_{{ id }}
      body.append(rendered);
      $("#stbody_" + this.id).append(result_rendered);
    }
  );
}

function get_job_history () {
  var get_append = $('form').serialize();
  var url = uri_base + "/rest/jobs/list.json?" + get_append;
  axios.get(url).then(update_job_history);
}

function change_page(page_counter) {
  var new_val = parseInt($("#page").val()) + page_counter;
  $("#page").val(new_val);
}

function next_page() {
  change_page(1);
  get_job_history();
  if ( parseInt($("#page").val()) > 1 ) {
    $("#previous_page").prop("disabled",false);
  }
}

function previous_page() {
  change_page(-1);
  get_job_history();
  if ( parseInt($("#page").val()) <= 1 ) {
    $("#previous_page").prop("disabled",true);
  }
}

$( document ).ready(function() {
  get_job_history();

  $(".cb_state").each( function (cb) {
    $( this ).change(get_job_history);
  });

  $("#search_button").click(function () {
	get_job_history();
  });

  $("#job_name").keydown(function(e) {
    if( e.keyCode === 13) {
      e.preventDefault();
      e.stopPropagation();
      e.stopImmediatePropagation();
      get_job_history();
      return;
    }
  });

  $("#next_page").click(function () {
    next_page();
  });
  $("#previous_page").click(function () {
    previous_page();
  });

  if ( parseInt($("#page").val()) <= 1 ) {
    $("#previous_page").prop("disabled",true);
  }

  $("#limit").change(function () {
    get_job_history();
  });

  $("#searchclear").click(function(){
    $("#job_name").val('');
    get_job_history();
  });
});
