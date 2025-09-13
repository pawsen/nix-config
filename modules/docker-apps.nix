{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.dockerApps;
in {
  options.services.dockerApps = {
    enable = mkEnableOption "Declarative dockerized apps with nginx reverse proxy";

    apps = mkOption {
      type = types.attrsOf (types.submodule ({
        options = {
          # Docker image
          image = mkOption {
            type = types.str;
            description = "Docker image to run (e.g., nginx:latest)";
          };

          # Ports
          containerPort = mkOption {
            type = types.int;
            description = "Port exposed inside the container";
          };
          hostPort = mkOption {
            type = types.int;
            description = "Port exposed on the host";
          };

          # Nginx / domain
          domain = mkOption {
            type = types.str;
            description = "Domain/subdomain for nginx reverse proxy";
          };
          enableACME = mkOption {
            type = types.bool;
            default = false;
            description = "Enable Let's Encrypt certificates (requires public DNS)";
          };
          addSSL = mkOption {
            type = types.bool;
            default = false;
            description = "Enable SSL in nginx (requires ACME or custom certs)";
          };

          # Environment variables
          environment = mkOption {
            type = types.attrsOf types.str;
            default = {};
            description = "Environment variables for the container";
          };

          # Volume mounts
          volumes = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "List of volume mounts, e.g. [ \"/host/path:/container/path\" ]";
          };
        };
      }));
      default = {};
      description = "Docker applications to run with reverse proxy";
    };
  };

  config = mkIf cfg.enable {
    # Make sure Docker is enabled
    virtualisation.docker = {
      enable = true;
      storageDriver = "btrfs";
      daemon.settings = {
          # https://nixos.wiki/wiki/Docker#Changing_Docker_Daemon.27s_Other_settings_example
          userland-proxy = false;
          experimental = true;
          metrics-addr = "0.0.0.0:9323";
          ipv6 = true;
          fixed-cidr-v6 = "fd00::/80";

          # Changing Docker Daemon's Data Root
          data-root = "/data/docker";
      };
    };

    # Systemd services for each app
    systemd.services = mkMerge (mapAttrsToList (name: app: {
      "docker-${name}" = {
        description = "Docker container ${name}";
        after = [ "network.target" "docker.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          ExecStart = ''
            ${pkgs.docker}/bin/docker run --rm \
              --name ${name} \
              -p ${toString app.hostPort}:${toString app.containerPort} \
              ${concatStringsSep " " (mapAttrsToList (k: v: "-e ${k}=${v}") app.environment)} \
              ${concatStringsSep " " (map (v: "-v ${v}") app.volumes)} \
              ${app.image}
          '';
          ExecStop = "${pkgs.docker}/bin/docker stop ${name}";
        };
      };
    }) cfg.apps);

    # Nginx reverse proxy for each app + default catch-all
    services.nginx.enable = true;
    services.nginx.virtualHosts = lib.mkMerge (
      # 1. Docker app vhosts
      (mapAttrsToList (_: app: {
        "${app.domain}" = {
          root = "/var/www/${app.domain}";
          enableACME = app.enableACME;
          addSSL = app.addSSL;
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString app.hostPort}";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };
        };
      }) cfg.apps)
      # 2. Default catch-all vhost
      ++ [
        {
          _ = {
            root = "/var/www/default";
            locations."/" = {
              tryFiles = "$uri =404";
            };
          };
        }
      ]
    );
  };
}
