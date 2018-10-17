var header_template                 = $("#job_history_header").html();
var job_result_template             = $("#job_result_panel").html();
var subtask_result_template         = $("#subtask_result_panel").html();

var subtask_result_success_template = $("#subtask_result_success").html();
var subtask_result_failed_template  = $("#subtask_result_failed").html();
var job_result_failed_template  = $("#job_result_failed").html();

Mustache.parse(header_template);
Mustache.parse(job_result_template);
Mustache.parse(subtask_result_success_template);
Mustache.parse(subtask_result_failed_template);
Mustache.parse(job_result_failed_template);

var alert_map =[];
alert_map['succeed'] = 'success';
alert_map['running'] = 'info';
alert_map['failed']  = 'danger';
alert_map['skipped']  = 'warning';
alert_map['dispatching']  = 'warning';

function update_job_result(xhr) {
  var data = xhr.data;
  $("#job_result").empty();

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

  $("#job_result").append(rendered);


  var job = data;

      var alert_map =[];
      alert_map['succeed']  = 'success';
      alert_map['running']  = 'info';
      alert_map['failed']   = 'danger';
      alert_map['skipped']  = 'warning';
      alert_map['dispatching']  = 'warning';

      var duration_min = 0;
      var duration_sec = 0;
      var start_time   = 0;


      if ( job.start_time ) {
        start_time = new Date(1000 * job.start_time);
        var due = Math.floor(Date.now() / 1000);

        if ( this.end_time ) { due = job.end_time; }

        var duration = due - job.start_time;
        duration_min = Math.floor( duration / 60 );
        duration_sec = duration % 60;
      }

      var rendered = Mustache.render(
                      job_result_template,
                      {
                        id            : job.id,
                        name          : job.name,
                        start_time    : ( start_time ) ? start_time.toLocaleString() : "not started yet",
                        duration_min  : duration_min,
                        duration_sec  : duration_sec,
                        state_class   : alert_map[job.state],
                      }
      );
      $("#job_result").append(rendered);
      update_job_result_panel_body(data);
}

function update_job_result_panel_body (data) {

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

function toggle_subtask_result_body (subtask_id) {

  var element = $('#stbody_' + subtask_id );
  var css_display = element.css("display");

  if ( css_display == "none" ) {
      element.css("display","block");
  } else {
      element.css("display","none");
  }
}

function get_job_result () {

  var get_append = $('form').serialize();
  var job_history_id = $('#jr_form').find('input[name="job_history_id"]').val();
  var url = uri_base + "/rest/job/" + job_history_id + ".json";

  axios.get(url).then(update_job_result);
}

$( document ).ready(function() {
  get_job_result();
});
