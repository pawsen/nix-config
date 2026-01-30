{ config, pkgs, lib, ... }:

let
  cfg = config.services.torrent;
  snippetPath = "/etc/caddy/snippets/torrent-auth";
  # siteAddr = if cfg.enableHTTPS then cfg.domain else "http://${cfg.domain}";
  siteAddr = cfg.domain;

  torrentUser = "torrent";
in {
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
      description =
        "If false, force HTTP only (tls off). If true, allow Caddy automatic HTTPS (ACME) for the domain.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${torrentUser} = { };
    users.users.${torrentUser} = {
      isSystemUser = true;
      description = "Transmission daemon user";
      createHome = true;
      home = "/var/lib/torrent";
      group = torrentUser;
    };

    systemd.tmpfiles.rules = [
      # systemd.tmpfiles.rules is evaluated by systemd-tmpfiles --create during boot/activation and
      # it is not mount-aware.
      # "d /data/torrents 0755 ${torrentUser} ${torrentUser} -"
      "d /etc/caddy/snippets 0750 root caddy -"
    ];

    # only create /data/torrent if /data is mounted
    systemd.services.transmission = {
      requires = [ "data.mount" ];
      after = [ "data.mount" ];

      serviceConfig = {
        # Ensure systemd pulls the mount in when starting transmission
        RequiresMountsFor = [ "/data" ];
        # Hard stop: do nothing unless /data is actually mounted
        ConditionPathIsMountPoint = "/data";

        # Create /data/torrent
        ExecStartPre = [
          "/run/current-system/sw/bin/install -d -m 0755 -o ${torrentUser} -g ${torrentUser} /data/torrents"
        ];
      };
    };

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
        # delete rpc-url if using a subdomain like torrent.url
        rpc-url = "/torrent/";

        rpc-whitelist-enabled = false;
        rpc-host-whitelist-enabled = false;
      };
    };

    services.caddy.enable = true;
    services.caddy.virtualHosts.${siteAddr}.extraConfig = ''
      @torrentNoSlash path /torrent
      redir @torrentNoSlash /torrent/ 308

      @not_tailscale not remote_ip 100.64.0.0/10
      handle /torrent/* {
          basic_auth @not_tailscale {
              import ${snippetPath}
          }
          reverse_proxy 127.0.0.1:9091
      }
    '';
  };
}
