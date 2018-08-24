var alert_map = {
  succeed: 'alert-success',
  failed:  'alert-danger',
  running:  'alert-primary',
};

function calc_job_start_and_end(start_time, end_time) {
  var st = new Date(1000 * start_time);
  if (st) {
    // calculate duration
    var due;

    if ( end_time ) { 
      due = end_time; 
    } else {
      due = Math.floor(Date.now() / 1000);
    }

    var duration = due - start_time;
    duration_min = Math.floor( duration / 60 );
    duration_sec = duration % 60;

    // (start_time_formatted, duration_formatted)
    return [st.toLocaleString(), duration_min +" min "+duration_sec+" sec"];
  } else {
    return ["not started", "not started"];
  }
}

function calc_additional_job_parameters(job) {
        job.state_class = alert_map[job.state];
        var r = calc_job_start_and_end(job.start_time, job.end_time);
        job.start_time_formatted = r[0];
        job.duration             = r[1];
};

Vue.component('worker-info',{
  data: function() {
    return {
      worker: {
        host:  '',
        queue: '',
        pid:   ''
      }
    }
  },
  template: '<div class="worker_info">'
    + '  <div class="row">'
    + '    <div class="col-md-2">'
    + '      Worker Name'
    + '    </div>'
    + '    <div class="col-md-10">'
    + '      {{ worker.host }}'
    + '    </div>'
    + '  </div>'
    + '  <div class="row">'
    + '    <div class="col-md-2">'
    + '      Worker PID'
    + '    </div>'
    + '    <div class="col-md-10">'
    + '      {{ worker.pid }}'
    + '    </div>'
    + '  </div>'
    + '  <div class="row">'
    + '    <div class="col-md-2">'
    + '      Worker Queue'
    + '    </div>'
    + '    <div class="col-md-10">'
    + '      {{ worker.queue }}'
    + '    </div>'
    + '  </div>'
    + '</div>'
});

Vue.component('task-card',{
  props: ['task'],
  data: function() {
    return {
      showTaskResult: 0
    }
  },
  methods: {
    toggleTaskDetails: function() {
      this.showTaskResult = !this.showTaskResult;
    }
  },
  template: ''
    + '<div class="card task_card">'
    + '  <div class="card-header alert" v-bind:class="task.state_class" v-on:click="toggleTaskDetails()">'
    + '    <div class="row">'
    + '      <div class="col-md-12">'
    + '        <span class="badge badge-secondary">{{ task.id }}</span> {{ task.name }}'
    + '      </div>'
    + '    </div>'
    + '  </div>'
    + '  <div class="card-body" v-show="showTaskResult">'
    + '    <task-result v-bind:result="task.result"></task-result>'
    + '  </div>'
    + '</div>'
});

Vue.component('task-result',{
  props: ['result'],
  template: '<div class=container>'
    + '<template v-if="result.error_message">'
    + '  <pre>{{ result.error_message}}</pre>'
    + '</template>'
    + '<template v-if="result.prepare">'
    + '  <div class="row">'
    + '    <div class="col-md-2">prepare:</div><div class="col-md-10">{{ result.prepare.message }}</div>'
    + '  </div>'
    + '</template>'
    + '<template v-if="result.execute">'
    + '  <div class="row">'
    + '    <div class="col-md-2">execute:</div><div class="col-md-10">{{ result.execute.message }}</div>'
    + '  </div>'
    + '</template>'
    + '<template v-if="result.finalize">'
    + '  <div class="row">'
    + '    <div class="col-md-2">finalize:</div><div class="col-md-10">{{ result.finalize.message }}</div>'
    + '  </div>'
    + '</template>'
    + '</div>'
});

Vue.component('task-list',{
  data: function() {
    return {
      isShown: 0,
      count: 0,
      jobData: {}
    }
  },
  updated: function() {
    this.$refs.workerinfo.worker = {
      host: this.jobData.workerhost,
      pid:  this.jobData.workerpid,
      queue: this.jobData.workerqueue
    };
    calc_additional_job_parameters(this.jobData);
    this.$parent.job = this.jobData;
  },
  template: '<div class="card-body">'
    + '  <worker-info ref="workerinfo"></worker-info>'
    + '  <task-card v-bind:key="task.id" v-bind:task="task" v-for="task in jobData.subtasks"></task-card>'
    +'</div>'
});


Vue.component('job-card',{
  props: ['job'],
  data: function () {
    return {
      showTaskList: 0,
      uri_base:     uri_base
    }
  },
  methods: {
    toggleJobDetails: function() {
      this.showTaskList = !this.showTaskList
      this.$refs.tasklist.isShown = ! this.$refs.tasklist.isShown;
      this.$refs.tasklist.count++;
      var job  = this.job;
      var url = uri_base + "/rest/job/"+job.id+".json";
      var self = this;
      axios.get(url).then(function(response) {
        self.$refs.tasklist.jobData = response.data;
        response.data.subtasks.forEach(function(task) {
           task.state_class = alert_map[task.state];
           task.result      = task.result || {};
        });
      });
    },
  },
  template: '<div class="card job_card">'
    + '<div class="card-header alert" v-bind:class="job.state_class">'
    + '  <div class="row">'
    + '    <div class="col-md-6" v-on:click="toggleJobDetails()">'
    + '      <span class="badge badge-secondary">{{ job.id }}</span> {{ job.name }}'
    + '    </div>'
    + '    <div class="col-md-2">'
    + '      {{ job.start_time_formatted }}'
    + '    </div>'
    + '    <div class="col-md-2">'
    + '      {{ job.duration }}'
    + '    </div>'
    + '    <div class="col-md-2">'
    + '      <!-- ACTIONS -->'
    + '      <job-details-link v-bind:href="uri_base + \'/job_result/\'+job.id"></job-details-link>'
    + '    </div>'
    + '  </div>'
    + '</div>'
    + '<task-list v-show="showTaskList" ref="tasklist"></task-list>'
    + '</div>'
});

Vue.component('job-details-link',{
  props: ['job_id','uri_base'],
  template: '<a class="float-right" style="margin-left:5px;"><i class="fas fa-link"></i></a>'
});

/*
        {{#comments_icon }}
          <a class="float-right"
             href="#"
             data-toggle="modal"
             data-target="#modal_window_comment_{{id}}"
             style="margin-left:5px;">
               <i class="{{comments_icon}} fa-comments"/>
          </a>
        {{/comments_icon}}
        {{#pwrand}}
          <a class="float-right"
             href="#"
             data-toggle="modal"
             data-target="#modal_window_pwrand_{{id}}"
             data-placement="left"
             style="margin-left:5px;">
               <i class="fas fa-lock"></i>
          </a>
        {{/pwrand}}
*/

Vue.component('page-counter',{
  props: ['page'],
  template: '<div class="col-md-2">Page: <span class="badge badge-secondary">{{ page }}</span></div>'
});

Vue.component('prev-button',{
  methods: {
    prevpage: function() {
      if (this.$parent.page <= 1) {return}
      this.$parent.page--;
      this.$parent.updateJobList();
    }
  },
  template: '<div class="col-md-1"><button v-on:click="prevpage()" class="btn btn-default">&lt;&lt;&lt;</button></div>'
});

Vue.component('next-button',{
  methods: {
    nextpage: function() {
      this.$parent.page++;
      this.$parent.updateJobList();
    }
  },
  template: '<div class="col-md-1"><button v-on:click="nextpage()" class="btn btn-default">&gt;&gt;&gt;</button></div>'
});

Vue.component('limit-select',{
  data: function() {
    return {limit:10}
  },
  methods: {
    setNewLimit: function() {
      this.$parent.limit = this.limit;
      this.$parent.updateJobList();
    }
  },
  template: ''
    + '<div v-on:change="setNewLimit()">'
    + '  Show rows:'
    + '  <select v-model="limit">'
    + '    <option v-for="option in [5,10,20,50,100]" v-bind:value="option">{{ option }}</option>'
    + '  </select>'
    + '</div>'
});

Vue.component('job-search',{
  data: function() {
    return {job_name:''}
  },
  methods: {
    updateJobSearch: function() {
      this.$parent.job_name = this.job_name;
      this.$parent.updateJobList();
    },
    clearJobSearch: function() {
      this.job_name = '';
      this.$parent.job_name = this.job_name;
      this.$parent.updateJobList();
    }
  },
  template: ''
    + '    <div class="btn-group col-md-4">'
    + '       <input type="text" v-model="job_name" v-on:blur="updateJobSearch" v-on:keyup.enter="updateJobSearch" class="form-control" placeholder="Enter job name - Use \'%\' as wildcard">'
    + '      <span v-on:click="clearJobSearch()" style="margin-left:-20px;margin-top:10px;">'
    + '          <i class="far fa-times-circle"></i>'
    + '       </span>'
    + '    </div>'

});

Vue.component('job-state-checkbox',{
  props: ['name','state_class'],
  data: function() {
    return {job_states:['succeed','failed','dispatching','running']}
  },
  methods: {
    updateJobSearch: function() {
      this.$parent.job_states = this.job_states;
      this.$parent.updateJobList();
    },
  },
  template: ''
    + '    <div class="col col-md-3">'
    + '      <h5>'
    + '        <input type="checkbox" name="state" v-model="job_states" v-bind:value="name" class="cb_state" v-on:change="updateJobSearch" >'
    + '        <span v-bind:class="state_class">{{ name }}</span>'
    + '      </h5>'
    + '    </div>'
});

var vm = new Vue({
  el: '#vue_app',
  data: {
    jobs: {},
    page: 1,
    limit: 10,
    job_name: '',
    job_states: ['succeed','failed','dispatching','running']
  },
  methods: {
    updateJobList: function() {
     
      var url    = uri_base + "/rest/jobs/list.json";
      var self   = this;
      var params = {
        page:  self.page,
        limit: self.limit,
        state: self.job_states,
      };
      var params = new URLSearchParams();
      params.append("page",  self.page);
      params.append("limit", self.limit);

      self.job_states.forEach(function(state) { 
        params.append("state", state);
      });

      if (self.job_name) { params.append('job_name', self.job_name); }
      
      axios.get(url, { params: params }).then(function(response) {
	response.data.jobs.forEach(function(job) {
	  calc_additional_job_parameters(job);
	});
	self.jobs = response.data.jobs;
      });
    }
  },
  mounted: function() {
      this.updateJobList();
  }
})
