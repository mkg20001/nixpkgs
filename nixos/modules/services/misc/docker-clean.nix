{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.docker-clean; # unsure if it should be virtualisation.docker.docker-clean?
  # isDockerEnabled = config.virtualisation.docker.enable; # FIXME: infinite recursion
  isDockerEnabled = true;
in

{
  options = {
    services.docker-clean = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable docker-clean task";
      };

      interval = mkOption {
        type = types.str;
        default = "daily";
        description = "Interval at which the cleanup is executed";
      };

      stop = mkOption {
        type = types.bool;
        default = false;
        description = "Stop all running containers";
      };

      containers = mkOption {
        type = types.bool;
        default = false;
        description = "Remove all stopped containers";
      };

      images = mkOption {
        type = types.bool;
        default = false;
        description = "Remove all untagged images";
      };

      networks = mkOption {
        type = types.bool;
        default = false;
        description = "Remove empty networks";
      };

      ignoreCreated = mkOption {
        type = types.bool;
        default = false;
        description = "By default, CREATED containers are set to be removed.  Adding this" +
                      "flag will ensure that all created containers are not cleaned";
      };

      tagged = mkOption {
        type = types.bool;
        default = false;
        description = "Remove all tagged images";
      };

      all = mkOption {
        type = types.bool;
        default = false;
        description = "Stops and removes all Containers, Images, AND Restarts docker (overrides other options)";
      };

      log = mkOption {
        type = types.bool;
        default = false;
        description = "Adding this as an additional flag will list all"
                      "images, volumes, and containers deleted";
      };

      host = { # TODO: can we get that from virtualisation.docker?
        type = types.nullOr types.str;
        default = null;
        description = "Specifies the docker host to run against" +
                      "\nUseful for docker swarm maintenance ie: 127.0.0.1:4000";
      };
    };
  };

  config = mkIf cfg.enable
  (if (isDockerEnabled || (cfg.host != null)) then
    {
      environment.systemPackages = [
        pkgs.docker-clean
      ];

      systemd.services.docker-clean =
        let
          options = [];
            #++ (optional cfg.stop ["--stop"])
            #++ (optional cfg.containers ["--containers"])
            #++ (optional cfg.images ["--images"])
            #++ (optional cfg.networks ["--networks"])
            #++ (optional cfg.ignoreCreated ["--created"])
            #++ (optional cfg.tagged ["--tagged"])
            #++ (optional cfg.all ["--all"])
            #++ (optional cfg.log ["--log"])
            #++ (if cfg.host != null then ["--host" cfg.host] else []);
          args = escapeShellArgs options;
        in
        { description = "Docker Cleanup Script";
          script = "exec ${pkgs.docker-clean}/bin/docker-clean ${args}";
          startAt = cfg.interval;
        };
    }
  else builtins.throw "docker-clean works only when either docker is enabled or an external host is specified");
}
