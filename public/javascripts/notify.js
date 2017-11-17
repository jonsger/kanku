var mySocket = new WebSocket(ws_url);
var token = Cookies.get("kanku_notify_session");

mySocket.onmessage = function (evt) {
  console.log( "Got message " + evt.data );
  data = JSON.parse(evt.data);
  Notification.requestPermission(function() {
    var n = new Notification(data.title, {
	body: data.body,
	icon: './favicon.ico' // optional
    });
    n.onclick = function() {
        window.open(data.link, 'newwindow', "menubar=no");
        n.close();
    };
    setTimeout(n.close.bind(n), 20000);
  });
};

mySocket.onopen = function(evt) {
  console.log("opening Socket");
  setTimeout(
    function() {
      var msg = '{"token":"'+ token +'"}';
      console.log("sending token " + msg);
      console.log(msg)
      mySocket.send(msg);
    },
    2000
  );
  setTimeout(
    function() {
      mySocket.send('{"bounce":"Opened WebSocket successfully!"}');
    },
    2000
  );
};

mySocket.onclose = function(evt) {
  Notification.requestPermission(function() {
    var m = 'Closed WebSocket - no more messages will be displayed';
    var n = new Notification('Kanku Desktop Notification', {
	body: m,
	icon: './favicon.ico' // optional
    });
    $("#content").text(m);
    n.onclick = function() {
        window.location.href = 'notify';
        n.close();
    };
    setTimeout(n.close.bind(n), 20000);
  });
};

if (! window.Notification ) {
  alert("Notifications not availible in your browser!");
} else if (Notification.permission !== "granted") {
   Notification.requestPermission(function() {});
} else {
  $('#trigger_notify').click(
    function(){

    Notification.requestPermission(function() {
      var n = new Notification('Kanku Test Notification', {
	body: 'Test notification',
	icon: './favicon.ico' // optional
      });
      n.onclick = function() {
        window.location.href = 'job_history';
        n.close();
      };
      setTimeout(n.close.bind(n), 20000);
    });
  });
}
