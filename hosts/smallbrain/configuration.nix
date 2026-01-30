# nixos-rebuild switch --fast --flake .#smallbrain --build-host root@smallbrain.bleak-mine.ts.net  --target-host root@smallbrain.bleak-mine.ts.net

{ config, pkgs, lib, ... }:
let domain = "smallbrain.bleak-mine.ts.net";
in {

  # Add this line when disks are plugged in
  imports = [
    ./disko.nix
    ./../../modules/docker-apps.nix
    ./../../modules/torrent.nix
    ./../../modules/downloads.nix
    ./../../modules/media.nix
    ./../../modules/backup-btrbk.nix
    ./../../modules/backup-borg.nix
    ./../../modules/monitoring.nix
  ];
  networking.hostName = "smallbrain";
  time.timeZone = "Europe/Copenhagen";

  # backups
  services.backup-btrbk = {
    enable = true;
    targetDir = "/data/backup/btrbk";
    # the module will create a new dir, targetDir/lion, etc, for each client
    clients = {
      lion =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDp4dCTuHEi4m59sjzgWqeGeEXa3nYIhn/WnILvDtdOS btrbk@lion";
    };
  };
  services.backup-borg = {
    enable = true;
    targetDir = "/data/backup/borg";
    clients = {
      pi4 =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHZ9U9wUVY2s+2rqn4zShXwaHvbJKUVjgiz8rqYcFlne pi@pi4";
    };
  };

  # grafana and prometheus
  services.monitoring = {
    enable = true;
    domain = "${domain}";
  };
  services.dockerApps.enable = true;
  services.dockerApps.apps = {
    ### DBKK LIBRARY ####
    # git clone --depth 1 https://github.com/pawsen/library-org.git /data/apps/library-org
    # docker build -t library .
    # docker run -p 5000:5000 \
    #   -v $(pwd)/uploads:/app/uploads \
    #   -v $(pwd)/database:/app/database \
    #   -v "$(pwd)/library.cfg:/app/library.cfg" \
    #   library:latest
    library = {
      image = "library:latest";
      containerPort = 5000;
      hostPort = 5001; # external port on the server
      domain = "${domain}";
      path = "/apps/dbkk";
      volumes = [
        "/data/apps/library-org/database:/app/database"
        "/data/apps/library-org/uploads:/app/uploads"
        "/data/apps/library-org/library.cfg:/app/library.cfg"
      ];
      # optional environment variables
      environment = { SCRIPT_NAME = "/apps/dbkk"; };
    };
  };
  services.torrent = {
    enable = true;
    domain = domain;
    # domain = "torrent.smallbrain";
  };
  services.downloads = {
    enable = true;
    domain = domain;
    # domain = "downloads.smallbrain";
  };
  services.media = {
    enable = true;
    domain = domain;
    # domain = "torrent.smallbrain";
  };
  # Home page
  services.caddy.enable = true;
  # caddy validate --config /etc/caddy/caddy_config --adapter caddyfile
  # caddy adapt --config /etc/caddy/caddy_config  --adapter caddyfile | jq
  services.caddy.globalConfig = ''
    # free port 80 and 443 for tailscale funnel
    http_port 4443
    https_port 4443

    # Tailscale funnel proxy though 127.0.0.1. Caddy has to trust localhost for it to do basic auth
    # on client_ip(the proxied ip, remote_ip will be 127.0.0.1 due to the proxy)
    servers {
      trusted_proxies static 127.0.0.1 ::1
    }
  '';
  # Ensure this is appended by lib.mkAfter
  services.caddy.virtualHosts.${domain}.extraConfig = lib.mkAfter ''
    # Trusted networks: LAN + Tailscale
    @untrusted {
        header Tailscale-Funnel-Request ?1
        not client_ip 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 100.64.0.0/10 fd7a:115c:a1e0::/48
    }

    # tailscale cert smallbrain.bleak-mine.ts.net
    # Move certs to caddy readable place
    # install -d -o caddy -g caddy -m 0750 /var/lib/caddy/tailscale-certs
    # install -o caddy -g caddy -m 0440 /var/lib/tailscale/certs/smallbrain.bleak-mine.ts.net.crt \
    #    /var/lib/caddy/tailscale-certs/smallbrain.bleak-mine.ts.net.crt
    # install -o caddy -g caddy -m 0440 /var/lib/tailscale/certs/smallbrain.bleak-mine.ts.net.key \
    #    /var/lib/caddy/tailscale-certs/smallbrain.bleak-mine.ts.net.key

    # Use the Tailscale-provided cert/key
    tls /var/lib/caddy/tailscale-certs/${domain}.crt /var/lib/caddy/tailscale-certs/${domain}.key

    # default web page
    handle {
      root * /data/www/
      file_server
    }
  '';

  # 1) Automatically GC old store paths
  nix.gc = {
    automatic = true;
    dates = "weekly"; # or "daily"
    options = "--delete-older-than 14d"; # tune
  };

  # 2) Keep only the last N system profiles (limits rollback generations)
  boot.loader.systemd-boot.configurationLimit = 5; # for systemd-boot

  environment.systemPackages = with pkgs; [ cryptsetup ];

  # This fails because /root (where the key is stored) is not mounted at stage 1 of the boot
  # process. Could maybe work if the key is at /hdd.key.
  # But as it is a non-root device, use crypttab to mount the drive at stage 2 (/root mounted)
  #  boot.initrd.luks.devices = {
  #    cryptdata1 = {
  #      # luksUUID from `cryptsetup luksUUID /dev/sd*
  #      device = "UUID=8b467c74-5538-431b-a507-2b8dfb858ac9";
  #      keyFile = "/root/hdd.key";
  #    };
  #  };

  systemd.tmpfiles.rules = [ "d /etc/keys 0700 root root -" ];

  age.secrets."hdd-key" = {
    file = ../../secrets/hdd.key.age;
    path = "/etc/keys/hdd.key";
    owner = "root";
    group = "root";
    mode = "0400";
  };
  # Don't set a too low timeout for spinning disks/usb interfaces.
  environment.etc."crypttab".text = ''
    cryptdata1 UUID=8b467c74-5538-431b-a507-2b8dfb858ac9 ${
      config.age.secrets."hdd-key".path
    } nofail
  '';
  fileSystems."/data" = {
    device = "/dev/mapper/cryptdata1";
    fsType = "btrfs";
    options = [
      "subvol=@data"
      "compress=zstd"
      "noatime"
      "nofail"
    ]; # "x-systemd.device-timeout=30s" ];
    # neededForBoot = false;
  };
  fileSystems."/backups" = {
    device = "/dev/mapper/cryptdata1";
    fsType = "btrfs";
    options = [
      "subvol=@backups"
      "compress=zstd"
      "noatime"
      "nofail"
    ]; # "x-systemd.device-timeout=30s" ];
    # neededForBoot = false;
  };

  # For simple DHCP wired network, systemd.network is not needed
  # systemd.network.enable = true;
  # use networkd as the network configuration backend or the legacy script based system. Note that
  # this option is experimental, enable at your own risk.
  # networking.useNetworkd = true;
  networking.useDHCP = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      userServices = true; # allow publishing custom services
      addresses = true; # publish this host’s addresses
      workstation = true; # publish as a workstation
    };
  };

  age.secrets.tailscaleAuthKey = {
    file = ../../secrets/tailscale-auth.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };
  services.tailscale = {
    enable = true;
    # Enables sysctls needed for exit node / routing
    useRoutingFeatures = "server";

    # Use the agenix-decrypted secret at activation/runtime
    authKeyFile = config.age.secrets.tailscaleAuthKey.path;

    # Make it an exit node (your “route traffic through this server” requirement)
    extraUpFlags = [
      "--advertise-exit-node"
      "--accept-dns=true" # optional; MagicDNS
    ];
  };

  system.stateVersion = "25.05"; # set at install time
}
