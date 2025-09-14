{ config, pkgs, lib, ... }:

let
  htpasswdPath = "/etc/nginx/htpasswd/torrent";
  # the datadir does not have to exist. The nixos module creates the dirs
  jellyfinDataDir = "/data/jellyfin";
in {
  options.services.media = {
    enable = lib.mkEnableOption "media player";
    domain = lib.mkOption {
      type = lib.types.str;
      example = "media.smallbrain";
      description = "Domain name for accessing the page.";
    };
  };

  config = lib.mkIf config.services.media.enable {
    services.jellyfin = {
      enable = true;
      # this open tcp: 8096, 8920. udp: 1900, 7359
      openFirewall = true;
      dataDir = jellyfinDataDir;
    };
    # XXX reverse proxy does not work:
    # maybe the reveser proxy IP has to be added in the JellyFin network tab,
    # In the GUI: setting under Advanced -> Networking.
    services.nginx = {
      enable = true;
      virtualHosts.${config.services.media.domain} = {
        locations."/".proxyPass = "http://127.0.0.1:8096";
        locations."/".proxyWebsockets = true;
        locations."/".extraConfig = ''
          auth_basic "Restricted";
          auth_basic_user_file ${htpasswdPath};

          # proxy_set_header Host $host;
          # proxy_set_header X-Real-IP $remote_addr;
          # proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          # proxy_set_header X-Forwarded-Proto $scheme;
          # proxy_set_header X-Forwarded-Protocol $scheme;
          # proxy_set_header X-Forwarded-Host $http_host;

          # # Disable buffering when the nginx proxy gets very resource heavy upon streaming
          # proxy_buffering off;
        '';

      #   locations."/socket".proxyPass = "http://127.0.0.1:8096";
      #   locations."/socket".extraConfig = ''
      #     proxy_http_version 1.1;
      #     proxy_set_header Upgrade $http_upgrade;
      #     proxy_set_header Connection "upgrade";
      #     proxy_set_header Host $host;
      #     proxy_set_header X-Real-IP $remote_addr;
      #     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      #     proxy_set_header X-Forwarded-Proto $scheme;
      #     proxy_set_header X-Forwarded-Protocol $scheme;
      #     proxy_set_header X-Forwarded-Host $http_host;
      #   '';
      };
    };
  };
}
