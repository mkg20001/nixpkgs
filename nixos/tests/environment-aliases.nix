import ./make-test.nix ({ pkgs, ...} : {
  name = "environment-aliases";
  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ mkg20001 ];
  };

  nodes = {
    machine = { config, lib, pkgs, ... }: {
      environment.aliases.test-alias = "true";
    };
  };

  testScript = {nodes, ...}: ''
    $machine->start();
    $machine->waitForUnit("default.target");

    $machine->succeed("test-alias");
  '';
})
