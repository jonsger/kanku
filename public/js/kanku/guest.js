function trigger_remove_domain (domain_name) {
  var data = [ {domain_name : domain_name}];
  axios.post(
    uri_base + "/rest/job/trigger/remove-domain.json",
    data
  ).then(
    function(xhr) {
      show_messagebox(xhr.data.state, xhr.data.msg );
    }
  );
}

$( document ).ready(
  function() {
    var guest_panel_template     = $("#guest_panel").html();
    Mustache.parse(guest_panel_template);

    var iface_line_template = $("#iface_line").html();
    Mustache.parse(iface_line_template);

    var addr_line_template = $("#addr_line").html();
    Mustache.parse(addr_line_template);

    var href_guest = $("#href_guest").html();
    Mustache.parse(href_guest);

    var url = uri_base + '/rest/guest/list.json';
    axios.get(url).then(function (xhr) {
        var gc     = xhr.data;
        var guests = gc;
        var gl = Object.keys(gc.guest_list).sort();
        var we = gc.errors;

        $.each(
          we,
          function (num, error) {
            $('#worker_errors').append(
              '<div class="alert alert-danger">'+error+'</div>'
            )
          }
        )

        $.each(
          //gc.guest_list,
	  gl,
          function (num,domain_name) {
	    var guest_data = gc.guest_list[domain_name];
            var r_guest_panel = Mustache.render(
                        guest_panel_template,
                        {
                          id                   : domain_name,
                          host                 : guest_data.host,
                          guest_class          : ( guest_data.state == 1 ) ? "success" : "warning",
                        }
            );

            $("#guest_list").append(r_guest_panel);

            if (active_roles.User && !active_roles.Admin && domain_name.match(user_name+'-.*')) {
              $("#guest_action_div_"+domain_name).append(
                '<a class="pull-right" href="#" onClick=trigger_remove_domain("'+domain_name+'")><span class="far fa-trash-alt"/></a>'
              );
            }

            $.each(
              guest_data.nics,
              function (i) {
                  var nic = this;

                  var r_iface_line = Mustache.render(
                          iface_line_template,
                          {
                            domain_name : domain_name,
                            name        : nic.name,
                            hwaddr      : nic.hwaddr
                          }
                  );
                  $("#gp_body_" + domain_name).append(r_iface_line);

                  if ( nic.addrs ) {

                    $.each(
                      nic.addrs,
                      function (j) {
                        var addr = this;
                        var r_address_line = Mustache.render(
                                addr_line_template,
                                addr
                        );

                        $("#addr_for_" + domain_name +"_"+nic.name ).append(r_address_line);


                    });

                };

            });

            $.each(
              guest_data.forwarded_ports,
              function (host_ip,forwarded_ports) {
                $.each(
                  forwarded_ports,
                  function(host_port,gp) {
                    var gen_href   = 0;
                    var guest_port = gp[0];
                    var proto      = gp[1];

                    if ( guest_port == 443 || proto == 'https') {
                      gen_href = 1;
                      proto    = 'https';
                    } else if ( guest_port == 80 || proto == 'http') {
                      gen_href = 1;
                      proto    = 'http';
                    } else if ( guest_port == 22 || proto == 'ssh') {
                      $("#gp_body_" + domain_name).append(
                        "<pre>ssh -l root -p "+host_port+" -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null "+host_ip+"</pre>"
                      );
                    } else {
                      $("#gp_body_" + domain_name).append(
                        "<pre>Found unknown port forward ("+host_ip+") "+host_port+" => "+guest_port+" on guest</pre>"
                      );
                    }

                    if ( gen_href == 1 ) {
                      var href = Mustache.render(
                         href_guest,
                          {
                            proto      : proto,
                            host_ip    : host_ip,
                            host_port  : host_port,
                            guest_port : guest_port,
                          }
                      );
                      $("#gp_body_" + domain_name).append(href);
                    }
                  }
                );
              }
            );
            var href = window.location.href;
            var parts = href.split('#');
            var vm = parts[1];

            if ( vm == domain_name) {
                var element = $('#gp_body_' + vm );
                element.css("display","block");
            }
          });
    });
});
