{ config, pkgs, lib, ... }:

let
  cfg = config.services.media;
  snippetPath = "/etc/caddy/snippets/media-auth";
  siteAddr = if cfg.enableHTTPS then cfg.domain else "http://${cfg.domain}";
  jellyfinDataDir = "/data/jellyfin";

in {
  options.services.media = {
    enable = lib.mkEnableOption "media player";

    domain = lib.mkOption {
      type = lib.types.str;
      example = "media.smallbrain";
      description = "Domain name for accessing Jellyfin via reverse proxy.";
    };
    enableHTTPS = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Caddy automatic HTTPS (ACME).";
    };

  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      [ pkgs.jellyfin pkgs.jellyfin-web pkgs.jellyfin-ffmpeg ];
    services.jellyfin = {
      enable = true;
      # Jellyfin typically needs DLNA discovery ports, etc.
      # openFirewall = true;
      dataDir = jellyfinDataDir;
    };

    # Ensure /data is mounted before services that depend on it.
    systemd.services.jellyfin = {
      requires = [ "data.mount" ];
      after = [ "data.mount" ];
    };
    # jellyfin does not automatically create a custom data dir
    systemd.tmpfiles.rules = [
      "d ${jellyfinDataDir} 0755 jellyfin jellyfin -"
      "d /etc/caddy/snippets 0750 root caddy -"
    ];

    # Decrypt and install Caddy auth snippet via agenix
    age.secrets.media = {
      file = ../secrets/media-auth.age;
      path = snippetPath;
      owner = "root";
      group = "caddy";
      mode = "0640";
    };

    services.caddy.enable = true;
    services.caddy.virtualHosts.${siteAddr}.extraConfig = ''
      reverse_proxy 127.0.0.1:8096
    '';
  };
}
