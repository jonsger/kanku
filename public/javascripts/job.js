
// prepare templates from job.tt
//
var header_template     = $("#job_panel").html();
Mustache.parse(header_template);

var job_panel_body_template = $("#job_panel_body_template").html();
Mustache.parse(job_panel_body_template);

var template_module_header = $("#template_module_header").html();
Mustache.parse(template_module_header);

var template_formgroup = {
  text:     $("#template_formgroup_text").html(),
  checkbox: $("#template_formgroup_checkbox").html() ,
};

Mustache.parse(template_formgroup.text);
Mustache.parse(template_formgroup.checkbox);


// preload global gui_config
var gui_config;
//
function toggle_job_panel_body (job_panel_id) {

  var element = $('#jp_body_' + job_panel_id );
  var css_display = element.css("display");

  if ( css_display == "none" ) {
      element.css("display","block");
  }
  else
  {
      element.css("display","none");
  }
}

//
function schedule_job(job_name) {

  console.log("job_name: " + job_name);

  save_settings(job_name);

  var data = [];
  var cur_class_id = undefined;

  var input_elements = $("#job_args_" + job_name ).find("input");
  var sub_task_counter = -1;

  $.each(
    input_elements,
    function() {
      console.log("Triggering job for: " + this.name + " " + this.value);

      if ( this.name == 'use_module' ) {
        cur_class_id = this.value;
        sub_task_counter = sub_task_counter + 1
        data[sub_task_counter]={};
      } else {
        if ( sub_task_counter > -1 ) {
          if ( this.type == "checkbox" ) {
            data[sub_task_counter][this.name] = this.checked;
          } else {
            data[sub_task_counter][this.name] = this.value;
          }
        }
      }
    }
  );

  console.log(JSON.stringify(data));

  $.post(
    uri_base + "/rest/job/trigger/" + job_name + ".json",
    JSON.stringify(data),
    function(response) {
      $("#schedule_result").removeClass("alert-success");
      $("#schedule_result").removeClass("alert-warning");
      $("#schedule_result").addClass("alert-" + response.state);
      $("#schedule_result").text(response.msg);
      $("#schedule_result").fadeIn();
      $("#schedule_result").delay(10000).fadeOut("slow");
    }
  );

}

function save_settings(job_id) {

  var j_string = Cookies.get("kanku_job");
  var obj;

  if ( j_string === undefined ) {
    obj = {};
  } else {
    obj = jQuery.parseJSON(j_string);
  }

  $.each(
    $("#job_args_" + job_id ).find("input"),
    function (element) {
      console.log( this.name + " " + this.id + " " + this.value);
      console.log(  );
      if ( this.type == "checkbox" ) {
        obj[this.id] = this.checked;
      } else {
        obj[this.id] = this.value;
      }
    }
  );

  Cookies.set(
    "kanku_job",
    obj
  );


}

function  restore_defaults(job_name) {
  
  $.each(
    gui_config.config,
    function (job_id) {
    console.log("restore_defaults: job_id = " + job_id);
    // restore only for selected job
    if ( this.job_name == job_name ) {
      console.log( this );
        $.each(
          this.sub_tasks,
          function(subtask_id) {
            console.log("restore_defaults: subtask_id =" + subtask_id);
            console.log( this );
            var defaults = this.defaults;
            $.each(
              this.gui_config,
              function(param_id) {
                var final_job_id = this.param + "_" +job_id + "_" + subtask_id + "_" + param_id;
                $("#"+final_job_id).val(defaults[this.param]);
              }
            );
          }
        );
      }
  });

}


// prepare document and event handler

$( document ).ready(
  function() {

    $.get(
      uri_base + '/rest/gui_config/job.json',
      function (gc) { 
        gui_config = gc ;  

        var j_string = Cookies.get("kanku_job");
        var obj;

        if ( j_string === undefined ) {
          obj = {};
        } else {
          obj = jQuery.parseJSON(j_string);
        }


        $.each(
          gui_config.config,
          function (job_id) {
            //console.log("job_name " + this.job_name);

            var job_name = this.job_name;
            var task_list = [];

            $.each(
              this.sub_tasks,
              function (subtask_id) {
                  var defaults = this.defaults;

                  var task_list_task_args = [];
                  $.each(
                    this.gui_config,
                    function (param_id) {
                      var tmpl = template_formgroup[this.type];
                      var final_jobid = this.param + "_" +job_id + "_" + subtask_id + "_" + param_id;
                      //console.log("              value: "+ obj[final_jobid]);
                      var value = obj[final_jobid] || defaults[this.param];
                      task_list_task_args.push(
                        Mustache.render(
                                  tmpl,
                                  {
                                    label       : this.label,
                                    param       : this.param,
                                    id          : final_jobid,
                                    value       : value,
                                    checked     : ( ( (this.type == "checkbox" ) && value == 1 ) ? "checked" : "" )
                                  }

                        )
                      );
                    }
                  );
                  //$("#job_args_"+job_name).append(
                  task_list.push(
                    Mustache.render(
                      template_module_header,
                      {
                        name      : job_name,
                        use_module: this.use_module,
                        task_args: task_list_task_args
                      }
                    )
                  );

              }
            );
            var rendered = Mustache.render(
                        header_template,
                        {
                          name          : this.job_name,
                          id            : this.job_name,
                          task_list     : task_list
                        }
            );

            $("#job_list").append(rendered);
          }
        );



        var j_string = Cookies.get("kanku_job");
        var obj;

        if ( j_string === undefined ) {
          obj = {};
        } else {
          obj = jQuery.parseJSON(j_string);
        }

        $.each(
          obj,
          function(k,v) {
            $("#"+k).val(v);
          }
        );
      }
    );
  }
);

