var updateMessageBar = function (p, t, s) {
    var mb = p.$data.message_bar;
    mb.show        = true;
    mb.alert_class = "alert-" + s;
    mb.text        = t;
    setTimeout(
      function() {
	console.log("Closing");
	mb.show = false;
      },
      10000
    );
  };

Vue.component('role-checkbox', {
  props: ['name', 'checked', 'value'],
  template: '<div class="form-group row">'
            + '<label class="col-sm-2 control-label">'
            + '{{ name }} '
            + '</label>'
            + '<div class="col-sm-10">'
            + '<input class="role_checkbox" type=checkbox v-bind:value="value" v-model="checked">'
            + '</div>'
            + '</div>'
});

var app = new Vue({
  el: '#user-details',
  data: {
    user_details: {},
    message_bar: {
      text:        'No message',
      show:        false,
      alert_class: 'alert-danger'
    },
    alert_class: '',
  },
  mounted: function() {
      var url  = uri_base + "/rest/user/"+ user_name +".json";
      var self = this;
      axios.get(url).then(function(response) {
	self.user_details = response.data;
      });
  },
  methods: {
    sendRoleRequest() {
      var roles   = new Array();
      var comment = $('textarea#comment').val();
      $('.role_checkbox').each(function(idx, elem) {
       if ($(elem).is(':checked')) { roles.push($(elem).attr('value')); }
      });
      var request = { 'roles' : roles, 'comment' : comment }
      var url     = uri_base + "/rest/request_roles.json";
      var self    = this;

      axios.post(url, request).then(function(response) {
        updateMessageBar(self, response.data.msg, response.data.state);
      });
    },
    updateUserData() {
      var self    = this;
      var ud      = self.$data.user_details;
      var url     = uri_base + "/rest/user/" + ud.id + ".json";
      var request = ud;
      axios.put(
        url,
        request,
      ).then(function(response) {
        updateMessageBar(self, response.data.msg, response.data.state);
      }).catch(function(error) {
        updateMessageBar(self, error.response.data, "alert-danger");
      });
    },
  },
});
