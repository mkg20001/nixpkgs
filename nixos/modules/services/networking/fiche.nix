{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.services.fiche;
in
{
  options = {
    services.fiche = {
      enable = mkEnableOption "fiche";
      outputDirectory = mkOption {
        type = types.str;
        description = "Output directory to write texts to";
        default = "/var/lib/fiche";
      };
      slugSize = mkOption {
        type = types.nullOr types.int;
        description = "Slug size";
        default = null;
      };
      domain = mkOption {
        type = types.nullOr types.str;
        description = "Domain";
        default = null;
      };
      port = mkOption {
        type = types.port;
        description = "Port";
        default = 9999;
      };
      bufferSize = mkOption {
        type = types.nullOr types.int;
        description = "Buffer size";
        default = null;
      };
      banlist = mkOption {
        type = types.nullOr types.path;
        description = "Banlist";
        default = null;
      };
      whitelist = mkOption {
        type = types.nullOr types.path;
        description = "Whitelist";
        default = null;
      };

      nginx = mkEnableOption "nginx configuration for fiche";
      openFirewall = mkEnableOption "open port in firewall";
    };
  };
  config = mkIf (cfg.enable) {
    systemd.services.fiche = {
      /*
             [-d domain] [-p port] [-s slug size]
             [-o output directory] [-B buffer size] [-u user name]
             [-l log file] [-b banlist] [-w whitelist] [-S]
      */
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.fiche}/bin/fiche -L :: " +
          "-o ${cfg.outputDirectory} " +
          "${optionalString (cfg.domain != null) "-d ${cfg.domain}"} " +
          "-p ${toString cfg.port} " +
          "${optionalString (cfg.slugSize != null) "-s ${toString cfg.slugSize}"} " +
          "${optionalString (cfg.bufferSize != null) "-B ${toString cfg.bufferSize}"} " +
          "${optionalString (cfg.banlist != null) "-b ${cfg.banlist}"} " +
          "${optionalString (cfg.whitelist != null) "-w ${cfg.whitelist}"} " +
          "-l /var/log/fiche/fiche.log";
        DynamicUser = true;
        User = "fiche";
        # ReadWritePaths = optionalString (cfg.outputDirectory != "/var/lib/fiche") "${cfg.outputDirectory}";
        StateDirectory = "fiche";
        LogsDirectory = "fiche"; 
        AmbientCapabilities = "CAP_NET_BIND_SERVICE";
      };
    };

    networking = mkIf (cfg.openFirewall) {
      firewall.allowedTCPPorts = [ cfg.port ];
    };

    services.nginx = mkIf (cfg.nginx) {
      virtualHosts.${cfg.domain} = {
        locations."/".alias = cfg.outputDirectory;
      };
    };
  };
}
