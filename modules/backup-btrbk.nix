{ lib, config, pkgs, ... }:

let
  cfg = config.services.backup-btrbk;
in {
  options.services.backup-btrbk = {
    enable = lib.mkEnableOption "btrbk SSH target (receive backups from clients)";

    targetDir = lib.mkOption {
      type = lib.types.str;
      default = "/data/backup/btrbk";
      description = "Base directory on btrfs where client backups are received.";
    };

    clients = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Map of clientName -> SSH public key.";
      example = {
        lion  = "ssh-ed25519 AAAA... lion";
        tiger = "ssh-ed25519 AAAA... tiger";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # create backup dir
    systemd.tmpfiles.rules =
      [ "d ${cfg.targetDir} 0750 btrbk btrbk -" ]
      ++ (lib.mapAttrsToList (name: _key:
            "d ${cfg.targetDir}/${name} 0750 btrbk btrbk -"
         ) cfg.clients);

    services.btrbk.sshAccess =
      lib.mapAttrsToList (name: key: {
        inherit key;
        roles = [ "target" "receive" "info" "delete" ];
      }) cfg.clients;

    environment.systemPackages = with pkgs; [ btrfs-progs btrbk lz4 mbuffer ];
  };
}
