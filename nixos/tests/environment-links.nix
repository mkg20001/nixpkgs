import ./make-test.nix ({ pkgs, ...} : {
  name = "environment-links";
  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ mkg20001 ];
  };

  nodes = {
    machine = { config, lib, pkgs, ... }: {
      environment.links = {
        "bin/bash".source = "${pkgs.bash}/bin/bash";
      };
    };
  };

  testScript = {nodes, ...}: ''
    $machine->start();
    $machine->waitForUnit("default.target");

    $machine->succeed("/bin/bash -c true");
  '';
})
