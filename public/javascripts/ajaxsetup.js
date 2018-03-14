$.ajaxSetup({
   'error' : function (xhr, state, error) {
      $('#content').append("<h2>An error occured while ajax call</h2>");
      $('#content').append("<pre>"+xhr.responseJSON.exception+"</pre>");
   }
});
