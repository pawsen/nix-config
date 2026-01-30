{ config, lib, pkgs, ... }:

let
  cfg = config.services.backup-borg;

  mkUser = name: {
    isSystemUser = true;
    group = "borg-${name}";
    home = "${toString cfg.targetDir}/${name}";
    createHome = true;
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keys = [
      (lib.concatStringsSep " " [
        ''
          command="borg serve --restrict-to-path ${
            toString cfg.targetDir
          }/${name}"''
        "restrict,no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty"
        cfg.clients.${name}
      ])
    ];
  };

in {
  options.services.backup-borg = {
    enable = lib.mkEnableOption
      "Borg repo endpoint for multiple clients (btrbk-like config)";

    targetDir = lib.mkOption {
      type = lib.types.path;
      default = "/data/backup/borg";
      description = "Base directory for per-client borg repositories.";
    };

    clients = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Map of clientName -> SSH public key.
        A per-client user borg-<clientName> will be created with access restricted to targetDir/<clientName>.
      '';
      example = { pi4 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... pi@pi4"; };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.borgbackup ];
    services.openssh.enable = lib.mkDefault true;

    # Ensure base directory exists
    systemd.tmpfiles.rules =
      [ "d ${toString cfg.targetDir} 0750 root root - -" ]
      ++ (lib.mapAttrsToList (name: _:
        "d ${
          toString cfg.targetDir
        }/${name} 0750 borg-${name} borg-${name} - -") cfg.clients);

    users.groups =
      lib.mapAttrs' (name: _: lib.nameValuePair "borg-${name}" { }) cfg.clients;

    users.users =
      lib.mapAttrs' (name: _: lib.nameValuePair "borg-${name}" (mkUser name))
      cfg.clients;
  };
}
