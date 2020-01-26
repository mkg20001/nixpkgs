# Test the firewall module.

let
  fw = machine: {
    services.nginx = {
      enable = true;
      virtualHosts."hello".locations."/".extraConfig = ''
        return 200 "Hello from ${machine}";
      '';
    };
    networking = {
      firewall.enable = true;
      nftables.enable = true;
      nftables.tables.lb = {
        family = "inet";
        content = ''
          chain prerouting {
            tcp dport 80 dnat ip to numgen inc mod 2 map { 0: lb1, 1: lb2 }
          }
        '';
      };
    };
  };
in
import ./make-test-python.nix ( { pkgs, ... } : {
  name = "lb-distrib";
  nodes = {
    lb1 = { ... }: (fw "lb1") // {
      
    };
    lb2 = { ... }: (fw "lb2") // {
      
    };
  };

  testScript = { nodes, ... }: ''
    start_all()
    lb1.wait_for_unit('nginx.service')
    lb2.wait_for_unit('nginx.service')
    lb1.wait_for_unit('firewall.service')
    lb2.wait_for_unit('firewall.service')
  '';
})
