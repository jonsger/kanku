var alert_map = {
  succeed:     'alert-success',
  failed:      'alert-danger',
  running:     'alert-primary',
  dispatching: 'alert-primary',
};

function calc_job_start_and_end(start_time, end_time) {
  if (start_time > 0) {
    var st = new Date(1000 * start_time);
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
    + '  <div class="row" v-show="worker.error">'
    + '    <div class="col-md-12">'
    + '      <pre>{{ worker.error }}</pre>'
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
  props: ['result'],
  data: function() {
    return {
      isShown: 0,
      count: 0,
      jobData: {},
    }
  },
  updated: function() {
    this.$refs.workerinfo.worker = {
      host:   this.jobData.workerhost,
      pid:    this.jobData.workerpid,
      queue:  this.jobData.workerqueue,
      error:  JSON.parse(this.jobData.result).error_message
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
    var show_comments     = false;
    var show_pwrand       = false;
    if (active_roles['Admin'] || active_roles['User']) {
      show_comments = true
    }
    if (active_roles['Admin'] && this.job.pwrand) {
      show_pwrand = true;
    }
    return {
      showTaskList:        0,
      uri_base:            uri_base,
      user_is_admin:       active_roles['Admin'],
      show_comments:       show_comments,
      show_pwrand:         show_pwrand,
      comment: '',
    }
  },
  computed: {
    workerInfo: function() {
      var tmp = new Array;
      if (this.job.workerinfo) {
        tmp = this.job.workerinfo.split(':');
      }
      return {
        host:  tmp[0] || 'localhost',
        pid:   tmp[1] || 0,
        queue: tmp[2] || ''
      }
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
    showModal: function() {
      this.$refs.modalComment.show()
    },
    closeModal: function() {
      this.$refs.modalComment.hide();
      this.$root.updateJobList();
    },
    createJobComment: function() {
      var url    = uri_base+'/rest/job/comment/'+this.job.id+'.json';
      var params = {job_id: this.job.id,message:this.comment};
      axios.post(url, params);
      this.updateJobCommentList();
      this.comment = '';
    },
    updateJobCommentList: function() {
      var url    = uri_base+'/rest/job/comment/'+this.job.id+'.json';
      var params = {job_id: this.job.id};
      var self = this;
      axios.get(url, params).then(function(response) {
        self.job.comments = response.data.comments;
      });
    },
  },
  template: '<div class="card job_card">'
    + '<div class="card-header alert" v-bind:class="job.state_class">'
    + '  <div class="row">'
    + '    <div class="col-md-6" v-on:click="toggleJobDetails()">'
    + '      <span class="badge badge-secondary">{{ job.id }}</span> {{ job.name }} ({{ workerInfo.host }})'
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
    + '      <pwrand-link v-show="show_pwrand" v-bind:job_id="job.id"></pwrand-link>'
    + '      <comments-link v-bind:job="job" ref="commentsLink"></comments-link>'
    + '    </div>'
    + '  </div>'
    + '</div>'
    + '<task-list v-show="showTaskList" ref="tasklist"></task-list>'
    + '  <b-modal ref="modalComment" hide-footer title="Comments for Job">'
    + '    <div>'
    + '      <single-job-comment v-for="cmt in job.comments" v-bind:key="cmt.id" v-bind:comment="cmt">'
    + '      </single-job-comment>'
    + '    </div>'
    + '    <div>'
    + '      New Comment:'
    + '      <textarea v-model="comment" rows="2" style="width: 100%"></textarea>'
    + '    </div>'
    + '    <div class="modal-footer">'
    + '      <button type="button" class="btn btn-success" v-on:click="createJobComment(job.id)">Add Comment</button>'
    + '      <button type="button" class="btn btn-secondary" v-on:click="closeModal()" aria-label="Close">Close</button>'
    + '    </div>'
    + '  </b-modal>'
    + '<pwrand-modal v-bind:job="job" ref="modalPwRand"></pwrand-modal>'
    + '</div>'
});

Vue.component('comments-link',{
  methods: {
    showModal: function() {
      var p = this.$parent;
      p.showModal();
    }
  },
  props: ['job'],
  computed: {
    comments_length: function() {
      if (this.job.comments) {
        return this.job.comments.length;
      }
      return 0;
    }
  },
  template: ''
    + '<a class="float-right" style="margin-left:5px;" v-on:click="showModal()">'
    + '  <span v-if="comments_length > 0" key="commented"><i class="fas fa-comments"></i></span>'
    + '  <span v-else><i class="far fa-comments" key="uncommented"></i></span>'
    + '</a>'
});

Vue.component('job-details-link',{
  template: '<a class="float-right" style="margin-left:5px;"><i class="fas fa-link"></i></a>'
});

Vue.component('pwrand-link',{
  props: ['job_id'],
  methods: {
    showModalPwRand: function() {
      var p0 = this.$parent;
      var r0 = p0.$refs.modalPwRand;
      var r1 = r0.$refs.modalPwRandModal;
      r1.show();
    },
  },
  template: '<a class="float-right" style="margin-left:5px;" v-on:click="showModalPwRand()"><i class="fas fa-lock"></i></a>'
});

Vue.component('pwrand-modal', {
  props: ['job'],
  template: ''
    + '<b-modal ref="modalPwRandModal" hide-footer title="Randomized Password">'
    + '<pre>'
    + 'gpg -d &lt;&lt;EOF |json_pp -f json -t dumper' + "\n"
    + '{{ job.pwrand }}'
    + "\n"
    + 'EOF'
    + '</pre>'
    + '</b-modal>'
});

Vue.component('single-job-comment', {
  props: ['comment'],
  methods: {
    editJobComment: function() {
      this.$refs.textarea_job_comment.readOnly = false;
      this.show_save = 1;
    },
    deleteJobComment: function() {
      var url    = uri_base+'/rest/job/comment/'+this.comment.id+'.json';
      var params = {comment_id: this.comment.id, };
      var self = this;
      var p = this.$parent;
      axios.delete(url, params).then(function(response) {
        p.$parent.updateJobCommentList();
      });
    },
    updateJobComment: function() {
      var url    = uri_base+'/rest/job/comment/'+this.comment.id+'.json';
      var params = {comment_id: this.comment.id, message: this.comment_message };
      var self = this;
      var p = this.$parent;
      axios.put(url, params).then(function(response) {
        p.$parent.updateJobCommentList();
      });
      this.$refs.textarea_job_comment.readOnly = true;
      this.show_save = 0;
    }
  },
  data: function() {
    return {
      show_mod: (user_name == this.comment.user.username) ? 1 : 0,
      show_save: 0,
      comment_message: this.comment.comment,
    }
  },
  template: ''
    + '<div class="panel panel-default">'
    + '  <div class="panel-heading">'
    + '    <div class=row>'
    + '      <div class=col-sm-9>'
    + '      {{ comment.user.username }} ({{comment.user.name}})'
    + '      </div>'
    + '      <div class="col-sm-3 text-right">'
    + '        <div v-show="show_mod">'
    + '          <button class="btn btn-primary" type="button" aria-label="Edit" v-on:click="editJobComment()">'
    + '            <i class="far fa-edit"></i>'
    + '          </button>'
    + '          <button class="btn btn-danger" type="button" aria-label="Delete" v-on:click="deleteJobComment()">'
    + '            <i class="far fa-trash-alt"></i>'
    + '          </button>'
    + '        </div>'
    + '      </div>'
    + '    </div>'
    + '   </div>'
    + '  <textarea v-model="comment_message" style="width:100%;margin-top:10px;margin-bottom:20px;" readonly ref="textarea_job_comment">'
    + '{{ comment.comment }}'
    + '</textarea>'
    + '   <button v-show="show_save" class="btn btn-success" v-on:click="updateJobComment()">Save</button>'
    + '</div>'
});

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
