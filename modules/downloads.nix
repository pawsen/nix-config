{ config, pkgs, lib, ... }:

let htpasswdPath = "/etc/nginx/htpasswd/torrent";
in {
  options.services.downloads = {
    enable = lib.mkEnableOption "list files in /data/downloads service";
    domain = lib.mkOption {
      type = lib.types.str;
      example = "downloads.smallbrain";
      description = "Domain name for accessing the page.";
    };
  };

  config = lib.mkIf config.services.downloads.enable {
    # Bind mount /data/torrent -> /data/downloads/torrents
    fileSystems."/data/downloads/torrents" = {
      device = "/data/torrents";
      fsType = "none";
      options = [ "bind" ];
    };
    services.nginx = {
      enable = true;
      virtualHosts.${config.services.downloads.domain} = {
        root = "/data/downloads";
        # Basic auth
        extraConfig = ''
          auth_basic "Restricted";
          auth_basic_user_file ${htpasswdPath};
          autoindex on;
        '';
      };
    };
  };
}
