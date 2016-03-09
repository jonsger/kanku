function toggle_guest_panel_body (guest_panel_id) {

  var element = $('#gp_body_' + guest_panel_id );
  var css_display = element.css("display");

  if ( css_display == "none" ) {
      element.css("display","block");
  }
  else
  {
      element.css("display","none");
  }
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


    $.get(
      uri_base + '/rest/guest/list.json',
      function (gc) {
        var guests = gc;

        $.each(
          gc.guest_list,
          function (domain_name,guest_data) {
            var r_guest_panel = Mustache.render(
                        guest_panel_template,
                        {
                          id          : domain_name,
                          guest_class : ( guest_data.state == 1 ) ? "success" : "warning"
                        }
            );

            $("#job_list").append(r_guest_panel);

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
              this.forwarded_ports,
              function (host_ip,forwarded_ports) {
                $.each(
                  forwarded_ports,
                  function(host_port,guest_port) {
                    var gen_href  = 0;
                    var proto     = '';
                    if ( guest_port == 443 ) {
                      gen_href = 1;
                      proto    = 'https';
                    } else if ( guest_port == 80 ) {
                      gen_href = 1;
                      proto    = 'http';
                    } else if ( guest_port == 22 ) {
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
                            proto     : proto,
                            host_ip   : host_ip,
                            host_port : host_port
                          }
                      );
                      $("#gp_body_" + domain_name).append(href);
                    }
                  }
                );
              }
            );
          }
        );
      }
    );
  }
);

