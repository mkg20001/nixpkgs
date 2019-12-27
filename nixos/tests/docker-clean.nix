import ./make-test.nix ({ pkgs, lib, ... }: {
  name = "docker-clean";
  meta = {
    maintainers = with lib.maintainers; [ mkg20001 ];
  };

  nodes = {
    docker = { pkgs, ... }:
      {
        virtualisation.docker.enable = true;
        services.docker-clean.enable = true;
      };
  };

  # TODO: add container that needs to be gone afterwards

  testScript = ''
    $docker->succeed("systemctl start docker-clean.service");
  '';
})
