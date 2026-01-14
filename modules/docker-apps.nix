{ config, lib, pkgs, ... }:

let
  inherit (lib)
    mkOption mkEnableOption types concatStringsSep mapAttrsToList mkMerge
    optionalString;
  cfg = config.services.dockerApps;
in {
  options.services.dockerApps = {
    enable =
      mkEnableOption "Declarative dockerized apps with Caddy reverse proxy";

    apps = mkOption {
      type = types.attrsOf (types.submodule ({
        options = {
          image = mkOption {
            type = types.str;
            description = "Docker image to run (e.g., ghcr.io/...:latest)";
          };
          containerPort = mkOption {
            type = types.int;
            description = "Container port exposed internally";
          };
          hostPort = mkOption {
            type = types.int;
            description = "Port exposed on the host";
          };
          domain = mkOption {
            type = types.str;
            description = "Domain/subdomain for Caddy reverse proxy";
          };
          path = mkOption {
            type = types.str;
            description = "Path, ie access the app at domain/path";
            default = "/";
          };
          environment = mkOption {
            type = types.attrsOf types.str;
            default = { };
            description = "Environment variables for the container";
          };
          volumes = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Volume mounts (e.g., /data/foo:/mnt/foo)";
          };
        };
      }));
      default = { };
      description = "Declarative docker apps";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      storageDriver = "btrfs";
    };

    virtualisation.docker.daemon.settings = {
      userland-proxy = false;
      experimental = true;
      metrics-addr = "127.0.0.1:9323";
      ipv6 = true;
      fixed-cidr-v6 = "fd00::/80";
      data-root = "/data/docker";
    };

    # Ensure /data is mounted before Docker
    # systemd.services.docker.requires = [ "data.mount" ];
    # systemd.services.docker.after = [ "data.mount" ];

    # One systemd service per declarative container
    systemd.services = mkMerge (mapAttrsToList (name: app: {
      "docker-${name}" = {
        description = "Docker container ${name}";
        after = [ "network.target" "data.mount" "docker.service" ];
        requires = [ "data.mount" "docker.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          # XXX: -p 127.0.0.1
          # only listen to localhost, ie we need a reverse proxy to access the container
          # if we want to access the container using a port number, use
          # -p ${toString app.hostPort}:${toString app.containerPort} \
          ExecStart = ''
            ${pkgs.docker}/bin/docker run --rm \
              --name ${name} \
              -p 127.0.0.1:${toString app.hostPort}:${
                toString app.containerPort
              } \
              ${
                concatStringsSep " "
                (mapAttrsToList (k: v: "-e ${k}=${v}") app.environment)
              } \
              ${concatStringsSep " " (map (v: "-v ${v}") app.volumes)} \
              ${app.image}
          '';
          ExecStop = "${pkgs.docker}/bin/docker stop ${name}";
        };
      };
    }) cfg.apps);

    # Caddy reverse proxy
    services.caddy.enable = true;
    services.caddy.virtualHosts = lib.mkMerge (mapAttrsToList (_: app:
      let
        siteAddr = app.domain;
        sitePath = if app.path == "" then "/" else app.path;

      in {
        "${siteAddr}" = {
          extraConfig = ''
            @m path ${sitePath}
            redir @m ${sitePath}/ 308

              handle ${sitePath}/* {
                reverse_proxy 127.0.0.1:${toString app.hostPort} {
              }
            }
          '';
        };
      }) cfg.apps);
  };
}
