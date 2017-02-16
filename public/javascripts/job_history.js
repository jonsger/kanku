var header_template                 = $("#job_history_header").html();
var job_result_template             = $("#job_result_panel").html();
var subtask_result_template         = $("#subtask_result_panel").html();

var subtask_result_success_template = $("#subtask_result_success").html();
var subtask_result_failed_template  = $("#subtask_result_failed").html();

Mustache.parse(header_template);
Mustache.parse(job_result_template);
Mustache.parse(subtask_result_success_template);
Mustache.parse(subtask_result_failed_template);

var alert_map =[];
alert_map['succeed'] = 'success';
alert_map['running'] = 'info';
alert_map['failed']  = 'danger';
alert_map['skipped']  = 'warning';

function update_job_history (data) {


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

      var duration_min = 0;
      var duration_sec = 0;

      var start_time = 0;

      if ( this.start_time ) {
        start_time = new Date(1000 * this.start_time);
        var due = Math.floor(Date.now() / 1000);
        if ( this.end_time ) {
          due = this.end_time;
        }
        var duration = due - this.start_time;
        duration_min = Math.floor( duration / 60 );
        duration_sec = duration % 60;

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
                      }
      );
      $("#job_history").append(rendered);
    }
  );
}

function update_job_result_panel_body (data) {

  var job_id = data.id;
  var body = $("#jbody_"+job_id);

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
          result =
            {
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
      //
      body.append(rendered);
      $("#stbody_" + this.id).append(result_rendered);
    }
  );

}


function toggle_job_result_body (job_history_id) {

  var element = $('#jbody_' + job_history_id );
  var css_display = element.css("display");

  if ( css_display == "none" ) {
      element.css("display","block");
      console.log("Reading job data");
      element.empty();
      var url = uri_base + "/rest/job/" + job_history_id + ".json";
      console.log(url);
      $.get(
        url,
        update_job_result_panel_body
      );

  }
  else
  {
      element.css("display","none");
  }

}

function toggle_subtask_result_body (subtask_id) {

  var element = $('#stbody_' + subtask_id );
  var css_display = element.css("display");

  if ( css_display == "none" ) {
      element.css("display","block");
  }
  else
  {
      element.css("display","none");
  }
}


function get_job_history () {
  var get_append = $('form').serialize();

  $.get(
    uri_base + "/rest/jobs/list.json?" + get_append,
    update_job_history
  );
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
