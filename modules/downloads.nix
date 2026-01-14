{ config, pkgs, lib, ... }:

let
  cfg = config.services.downloads;

  snippetPath = "/etc/caddy/snippets/downloads-auth";
  # siteAddr = if cfg.enableHTTPS then cfg.domain else "http://${cfg.domain}";
  siteAddr = cfg.domain;

  # Default bind set
  defaultBinds = [{
    from = "/data/torrents";
    to = "/data/downloads/torrents";
    mode = "0755";
  }];

  binds = if cfg.binds == [ ] then defaultBinds else cfg.binds;

  # Convenience: collect all dirs we must create (both sources and mountpoints).
  srcDirs = lib.unique (map (b: b.from) binds);
  dstDirs = lib.unique (map (b: b.to) binds);

  # For install -d we need parent dirs too; at least ensure /data/downloads exists.
  downloadsRoot = "/data/downloads";

  mkInstallDir = path: mode:
    "${pkgs.coreutils}/bin/install -d -m ${mode} ${lib.escapeShellArg path}";
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
    # List of bind mounts to create under /data/downloads (or elsewhere under /data).
    # If empty, a sane default is applied.
    binds = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule ({ ... }: {
        options = {
          from = lib.mkOption {
            type = lib.types.str;
            example = "/data/torrents";
            description =
              "Source directory (must exist on the /data filesystem).";
          };
          to = lib.mkOption {
            type = lib.types.str;
            example = "/data/downloads/torrents";
            description = "Destination mount point (bind mount target).";
          };
          mode = lib.mkOption {
            type = lib.types.str;
            default = "0755";
            example = "0750";
            description =
              "Permissions used when creating the directories (both from/to).";
          };
        };
      }));
      default = [ ];
      description = ''
        Bind mounts to create. These bind mounts are only attempted when /data is a mount point.
        If /data is not mounted, nothing is created under /data and the bind mounts are skipped.
      '';
    };

    # Optional: if true, do not start Caddy unless /data is mounted.
    # If false, Caddy runs but the /downloads page may error or be empty when /data is absent.
    requireDataForCaddy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Gate Caddy startup on /data being mounted.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [ "d /etc/caddy/snippets 0750 root caddy -" ];

    # Decrypt and install Caddy auth snippet via agenix
    age.secrets.downloads = {
      file = ../secrets/downloads-auth.age;
      path = snippetPath;
      owner = "root";
      group = "caddy";
      mode = "0640";
    };

    ##########################################################################
    # Create required dirs only after /data is mounted, and never on root fs.
    ##########################################################################
    systemd.services."downloads-create-data-dirs" = {
      description =
        "Create /data download bind dirs (only when /data is mounted)";
      wantedBy = [ "multi-user.target" ];

      # Make sure the /data mount is attempted first.
      requires = [ "data.mount" ];
      after = [ "data.mount" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;

        # Hard safety guard: do not create anything unless /data is a real mount.
        ConditionPathIsMountPoint = "/data";
      };

      script = ''
        set -euo pipefail

        # Ensure downloads root exists on the /data filesystem
        ${mkInstallDir downloadsRoot "0755"}

        # Create all source dirs (from) with requested modes
        # ${
          lib.concatStringsSep "\n" (map (b: mkInstallDir b.from b.mode) binds)
        }

        # Create all destination mount points (to) with requested modes
        ${lib.concatStringsSep "\n" (map (b: mkInstallDir b.to b.mode) binds)}
      '';
    };

    ##########################################################################
    # Bind mounts (systemd.mounts), skipped unless /data is mounted.
    ##########################################################################
    systemd.mounts = map (b: {
      what = b.from;
      where = b.to;
      type = "none";
      options = "bind";

      wantedBy = [ "multi-user.target" ];

      unitConfig = {
        # Do not even attempt the bind mount unless /data is mounted.
        ConditionPathIsMountPoint = "/data";

        # Ensure ordering and that dirs exist first.
        Requires = [ "data.mount" "downloads-create-data-dirs.service" ];
        After = [ "data.mount" "downloads-create-data-dirs.service" ];
      };

      mountConfig = {
        # Path-based dependency; ensures /data is pulled in.
        RequiresMountsFor = [ "/data" ];
      };
    }) binds;

    ##########################################################################
    # Caddy configuration
    ##########################################################################
    services.caddy.enable = true;

    # only run Caddy when /data is mounted: gate the service.
    systemd.services.caddy = lib.mkIf cfg.requireDataForCaddy {
      requires = [ "data.mount" ];
      after = [ "data.mount" ];
      serviceConfig = {
        RequiresMountsFor = [ "/data" ];
        ConditionPathIsMountPoint = "/data";
      };
    };

    services.caddy.virtualHosts.${siteAddr}.extraConfig = ''
      root * /data/downloads
      basic_auth /* {
        import ${snippetPath}
      }
      file_server browse
    '';
  };
}
