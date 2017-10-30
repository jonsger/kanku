if (! window.Notification ) {
  alert("Notifications not availible in your browser!");
} else if (Notification.permission !== "granted") {
   Notification.requestPermission(function() {});
} else {
  $('#trigger_notify').click(
    function(){

    Notification.requestPermission(function() {
      var n = new Notification('Kanku Desktop Notification', {
	body: 'test <a href="/kanku/job_history"> test test test test test test test test test test test test test test test test test test test test test test test test test test test ',
	icon: './favicon.ico' // optional
      });
      n.onclick = function() { 
        window.location.href = 'job_history';
      };
    });
  });
}
