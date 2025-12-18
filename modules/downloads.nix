{ config, pkgs, lib, ... }:

let
  cfg = config.services.downloads;
  snippetPath = "/etc/caddy/snippets/downloads-auth";
  siteAddr = if cfg.enableHTTPS then cfg.domain else "http://${cfg.domain}";

in {
  options.services.downloads = {
    enable = lib.mkEnableOption "List files in /data/downloads via Caddy";
    domain = lib.mkOption {
      type = lib.types.str;
      example = "downloads.smallbrain";
      description = "Domain name for accessing the page.";
    };
    enableHTTPS = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Caddy automatic HTTPS (ACME).";
    };
  };

  config = lib.mkIf cfg.enable {
    fileSystems."/data/downloads/torrents" = {
      device = "/data/torrents";
      fsType = "none";
      options = [ "bind" "nofail" ];
    };
    systemd.tmpfiles.rules = [ "d /etc/caddy/snippets 0750 root caddy -" ];

    # Decrypt and install Caddy auth snippet via agenix
    age.secrets.downloads = {
      file = ../secrets/downloads-auth.age;
      path = snippetPath;
      owner = "root";
      group = "caddy";
      mode = "0640";
    };

    services.caddy.enable = true;
    services.caddy.virtualHosts.${siteAddr}.extraConfig = ''
      root * /data/downloads
      basic_auth /* {
        import ${snippetPath}
      }
      file_server browse
    '';
  };
}
