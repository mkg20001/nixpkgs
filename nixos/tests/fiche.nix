import ./make-test-python.nix (
  { pkgs, ... }:
  {
    name = "fiche";
    meta = with pkgs.lib.maintainers; {
      maintainers = [ mkg20001 ];
    };

    nodes = {
      main =
        { config, ... }:
        {
          services.fiche = {
            enable = true;
            nginx = true;
            domain = "localhost";
          };
          services.nginx = {
            enable = true;
          };
          environment.systemPackages = [ pkgs.wget ];
        };
    };

    testScript = ''
      start_all()

      with subtest("ensure fiche starts and listens on 9999"):
          main.wait_for_unit("fiche.service")
          main.wait_for_open_port(9999)

      with subtest("ensure we can submit things"):
          main.succeed("echo hi | nc localhost 9999 > url")
          main.succeed("grep 'http://localhost/[a-zA-Z0-9][a-zA-Z0-9][a-zA-Z0-9][a-zA-Z0-9]' url")
      
      with subtest("ensure we can fetch things"):
          main.succeed("wget $(cat url) -O out")
          main.succeed("grep hi out")
    '';
  }
)
