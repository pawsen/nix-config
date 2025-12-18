{ config, pkgs, lib, ... }:

let
  cfg = config.services.torrent;
  snippetPath = "/etc/caddy/snippets/torrent-auth";
  siteAddr = if cfg.enableHTTPS then cfg.domain else "http://${cfg.domain}";
  torrentUser = "torrent";
in
{
  options.services.torrent = {
    enable = lib.mkEnableOption "Transmission torrent service via Caddy";

    domain = lib.mkOption {
      type = lib.types.str;
      example = "torrent.smallbrain";
      description = "Domain name for the torrent web interface.";
    };

    enableHTTPS = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "If false, force HTTP only (tls off). If true, allow Caddy automatic HTTPS (ACME) for the domain.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${torrentUser} = {};
    users.users.${torrentUser} = {
      isSystemUser = true;
      description = "Transmission daemon user";
      createHome = true;
      home = "/var/lib/torrent";
      group = torrentUser;
    };

    systemd.tmpfiles.rules = [
      "d /data/torrents 0755 ${torrentUser} ${torrentUser} -"
      "d /etc/caddy/snippets 0750 root caddy -"
    ];

    # Decrypt and install Caddy auth snippet via agenix
    age.secrets.torrent = {
      file = ../secrets/torrent-auth.age;
      path = snippetPath;
      owner = "root";
      group = "caddy";
      mode = "0640";
    };

    services.transmission = {
      enable = true;
      package = pkgs.transmission_4;
      user = torrentUser;
      group = torrentUser;
      home = "/var/lib/torrent";

      # RPC is proxied via Caddy; keep it local.
      openRPCPort = lib.mkForce false;
      openFirewall = lib.mkForce false;

      settings = {
        download-dir = "/data/torrents";
        incomplete-dir-enabled = false;

        rpc-bind-address = "127.0.0.1";
        rpc-port = 9091;

        rpc-whitelist-enabled = false;
        rpc-host-whitelist-enabled = false;
      };
    };

    services.caddy.enable = true;
    services.caddy.virtualHosts.${siteAddr}.extraConfig = ''
      basic_auth /* {
        import ${snippetPath}
      }
      reverse_proxy 127.0.0.1:9091
    '';
  };
}
