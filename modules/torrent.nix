{ config, pkgs, lib, ... }:

let
  torrentUser = "torrent";
  htpasswdPath = "/etc/nginx/htpasswd/torrent";
in {
  options.services.torrent = {
    enable = lib.mkEnableOption "Torrent client (Transmission) service";
    domain = lib.mkOption {
      type = lib.types.str;
      example = "torrent.smallbrain";
      description = "Domain name for accessing the torrent web interface.";
    };
  };

  config = lib.mkIf config.services.torrent.enable {
    users.groups.${torrentUser} = {};
    users.users.${torrentUser} = {
      isSystemUser = true;
      description = "Transmission daemon user";
      createHome = true;
      home = "/var/lib/torrent";
      group = torrentUser;
    };

    # try users.users.transmission
    systemd.tmpfiles.rules =
      [ "d /data/torrents 0755 ${torrentUser} ${torrentUser} -" ];

    services.transmission = {
      enable = true;
      package = pkgs.transmission_4;
      user = torrentUser;
      group = torrentUser;
      home = "/var/lib/torrent";
      openRPCPort = true;
      openFirewall = true;
      settings = {
        download-dir = "/data/torrents";
        incomplete-dir-enabled = false;
        rpc-bind-address = "127.0.0.1";
        rpc-port = 9091;
        # controls which IP addresses can access the RPC
        rpc-whitelist-enabled = false;
        # controls which hostnames are allowed in the Origin/Host header.
        # If enabled. the torren.domian has to added to the rpc-host list
        rpc-host-whitelist-enabled = false;

        # Uncomment to access directly through IP:9091
        # rpc-bind-address = "0.0.0.0";
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts.${config.services.torrent.domain} = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:9091";
          extraConfig = ''
            auth_basic "Restricted";
            auth_basic_user_file ${htpasswdPath};

            proxy_pass_header  X-Transmission-Session-Id;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };
    };
  };
}
